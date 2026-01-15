"""
Sentinel Bot - Power Management Cog
Cluster-wide power management commands for safe shutdown and startup.
"""

import logging
import asyncio
import discord
from discord import app_commands
from discord.ext import commands
from typing import TYPE_CHECKING, List, Optional
from dataclasses import dataclass, field
import time

from config import (
    PROXMOX_NODES, LXC_CONTAINERS,
    WOL_MAC_ADDRESSES, WOL_BROADCAST,
    NODE_SHUTDOWN_ORDER, NODE_STARTUP_ORDER,
    LXC_STARTUP_ORDER, CRITICAL_LXCS
)

if TYPE_CHECKING:
    from core import SentinelBot

logger = logging.getLogger('sentinel.cogs.power')

# Confirmation emojis
CONFIRM_EMOJI = "\u26a0\ufe0f"  # Warning sign
CANCEL_EMOJI = "\u274c"  # Red X


@dataclass
class PowerOperationReport:
    """Tracks results of power operations."""
    operation: str  # 'shutdown' or 'startup'

    nodes_total: int = 0
    nodes_success: int = 0
    nodes_failures: List[str] = field(default_factory=list)
    nodes_skipped: List[str] = field(default_factory=list)

    vms_total: int = 0
    vms_success: int = 0
    vms_failures: List[str] = field(default_factory=list)

    lxcs_total: int = 0
    lxcs_success: int = 0
    lxcs_failures: List[str] = field(default_factory=list)
    lxcs_skipped: List[str] = field(default_factory=list)

    start_time: float = field(default_factory=time.time)

    @property
    def duration(self) -> str:
        elapsed = time.time() - self.start_time
        minutes = int(elapsed // 60)
        seconds = int(elapsed % 60)
        return f"{minutes}m {seconds}s"

    @property
    def has_failures(self) -> bool:
        return bool(self.nodes_failures or self.vms_failures or self.lxcs_failures)

    def to_embed(self) -> discord.Embed:
        """Generate summary embed."""
        if self.operation == 'shutdown':
            if not self.has_failures:
                title = ":stop_button: Shutdown Complete"
                color = discord.Color.green()
            else:
                title = ":warning: Shutdown Completed with Errors"
                color = discord.Color.yellow()
        else:
            if not self.has_failures:
                title = ":arrow_forward: Startup Complete"
                color = discord.Color.green()
            else:
                title = ":warning: Startup Completed with Errors"
                color = discord.Color.yellow()

        embed = discord.Embed(title=title, color=color)
        embed.description = f"Completed in **{self.duration}**"

        # Node status
        node_emoji = ":white_check_mark:" if not self.nodes_failures else ":warning:"
        node_text = f"{node_emoji} {self.nodes_success}/{self.nodes_total}"
        if self.nodes_skipped:
            node_text += f"\n({len(self.nodes_skipped)} kept online)"
        embed.add_field(name=":desktop_computer: Nodes", value=node_text, inline=True)

        # VM status
        vm_emoji = ":white_check_mark:" if not self.vms_failures else ":warning:"
        embed.add_field(
            name=":computer: VMs",
            value=f"{vm_emoji} {self.vms_success}/{self.vms_total}",
            inline=True
        )

        # LXC status
        lxc_emoji = ":white_check_mark:" if not self.lxcs_failures else ":warning:"
        lxc_text = f"{lxc_emoji} {self.lxcs_success}/{self.lxcs_total}"
        if self.lxcs_skipped:
            lxc_text += f"\n({len(self.lxcs_skipped)} kept online)"
        embed.add_field(name=":package: LXCs", value=lxc_text, inline=True)

        # Failures section
        if self.has_failures:
            failures = []
            for f in self.nodes_failures[:3]:
                failures.append(f":desktop_computer: {f}")
            for f in self.vms_failures[:3]:
                failures.append(f":computer: {f}")
            for f in self.lxcs_failures[:3]:
                failures.append(f":package: {f}")
            if failures:
                embed.add_field(name=":x: Failures", value="\n".join(failures), inline=False)

        # Skipped section
        skipped_items = []
        for s in self.nodes_skipped:
            skipped_items.append(f":desktop_computer: {s}")
        for s in self.lxcs_skipped:
            skipped_items.append(f":package: {s}")
        if skipped_items:
            embed.add_field(name=":fast_forward: Kept Running", value="\n".join(skipped_items), inline=False)

        return embed


class PowerCog(commands.Cog, name="Power"):
    """Cluster-wide power management commands."""

    def __init__(self, bot: 'SentinelBot'):
        self.bot = bot
        self._pending_confirmations: dict = {}

    @property
    def ssh(self):
        return self.bot.ssh

    @property
    def config(self):
        return self.bot.config

    # ==================== Shutdown All ====================

    @app_commands.command(
        name="shutdownall",
        description="Gracefully shutdown all VMs, LXCs, and Proxmox nodes"
    )
    async def shutdown_all(self, interaction: discord.Interaction):
        """Shutdown the entire homelab cluster."""
        await interaction.response.defer()

        # Build summary of what will be affected
        summary_lines = []
        total_vms = 0
        total_lxcs = 0

        for node_name in NODE_SHUTDOWN_ORDER:
            node_ip = PROXMOX_NODES.get(node_name)
            if not node_ip:
                continue

            vms = await self.ssh.pve_get_running_vms(node_ip)
            lxcs = await self.ssh.pve_get_running_lxcs(node_ip)

            if vms or lxcs:
                summary_lines.append(f"**{node_name}** ({node_ip})")
                if vms:
                    summary_lines.append(f"  VMs: {', '.join(v['name'] for v in vms)}")
                    total_vms += len(vms)
                if lxcs:
                    summary_lines.append(f"  LXCs: {', '.join(l['name'] for l in lxcs)}")
                    total_lxcs += len(lxcs)

        await self._confirm_and_execute(
            interaction,
            operation="shutdownall",
            title=":stop_button: Confirm Full Cluster Shutdown",
            description=(
                "**This will shut down the ENTIRE homelab!**\n\n"
                f"**Resources to stop:**\n"
                f"- {total_vms} VMs\n"
                f"- {total_lxcs} LXC containers\n"
                f"- {len(PROXMOX_NODES)} Proxmox nodes\n\n"
                "**Shutdown order:**\n"
                "1. Stop all VMs (gracefully)\n"
                "2. Stop all LXC containers\n"
                "3. Shutdown all Proxmox nodes\n\n"
                ":warning: **Everything will be offline!**\n"
                "Use `/startall` to bring it back up."
            ),
            callback=self._perform_shutdown_all
        )

    # ==================== Shutdown (Keep DNS) ====================

    @app_commands.command(
        name="shutdown-nodns",
        description="Shutdown all except Pi-hole (DNS) and its host node"
    )
    async def shutdown_nodns(self, interaction: discord.Interaction):
        """Shutdown everything except Pi-hole for DNS availability."""
        await interaction.response.defer()

        # Get Pi-hole info
        pihole_info = CRITICAL_LXCS.get('pi-hole')
        pihole_node_ip = pihole_info[0] if pihole_info else None
        pihole_ctid = pihole_info[1] if pihole_info else None

        # Find which node to keep
        kept_node = None
        for name, ip in PROXMOX_NODES.items():
            if ip == pihole_node_ip:
                kept_node = name
                break

        # Build summary
        total_vms = 0
        total_lxcs = 0
        nodes_to_shutdown = []

        for node_name in NODE_SHUTDOWN_ORDER:
            node_ip = PROXMOX_NODES.get(node_name)
            if not node_ip:
                continue

            if node_ip == pihole_node_ip:
                continue  # Skip the node hosting Pi-hole

            nodes_to_shutdown.append(node_name)
            vms = await self.ssh.pve_get_running_vms(node_ip)
            lxcs = await self.ssh.pve_get_running_lxcs(node_ip)
            total_vms += len(vms)
            total_lxcs += len(lxcs)

        # Count LXCs on Pi-hole's node that will be stopped (excluding Pi-hole)
        if pihole_node_ip:
            lxcs_on_pihole_node = await self.ssh.pve_get_running_lxcs(pihole_node_ip)
            other_lxcs = [l for l in lxcs_on_pihole_node if l['ctid'] != pihole_ctid]
            total_lxcs += len(other_lxcs)

        await self._confirm_and_execute(
            interaction,
            operation="shutdown-nodns",
            title=":stop_button: Confirm Partial Shutdown (Keep DNS)",
            description=(
                "**This will shut down most of the homelab.**\n\n"
                f"**Kept running:**\n"
                f"- Pi-hole (LXC {pihole_ctid}) - DNS server\n"
                f"- {kept_node} ({pihole_node_ip}) - Pi-hole's host\n\n"
                f"**Will be stopped:**\n"
                f"- {total_vms} VMs\n"
                f"- {total_lxcs} LXC containers (excluding Pi-hole)\n"
                f"- {len(nodes_to_shutdown)} nodes ({', '.join(nodes_to_shutdown)})\n\n"
                ":information_source: DNS will remain available."
            ),
            callback=self._perform_shutdown_nodns
        )

    # ==================== Start All ====================

    @app_commands.command(
        name="startall",
        description="Wake all nodes via WoL and start all VMs/LXCs"
    )
    async def start_all(self, interaction: discord.Interaction):
        """Start the entire homelab cluster."""
        await interaction.response.defer()

        # Check which nodes are currently online
        online_nodes = []
        offline_nodes = []

        for node_name, node_ip in PROXMOX_NODES.items():
            is_online = await self.ssh.pve_is_node_online(node_ip)
            if is_online:
                online_nodes.append(node_name)
            else:
                offline_nodes.append(node_name)

        # Check for missing MAC addresses
        missing_macs = []
        for node_name in offline_nodes:
            mac = WOL_MAC_ADDRESSES.get(node_name)
            if not mac or mac == 'TBD':
                missing_macs.append(node_name)

        warning_text = ""
        if missing_macs:
            warning_text = (
                f"\n\n:warning: **Missing MAC addresses for:** {', '.join(missing_macs)}\n"
                "These nodes cannot be woken via WoL."
            )

        await self._confirm_and_execute(
            interaction,
            operation="startall",
            title=":arrow_forward: Confirm Full Cluster Startup",
            description=(
                "**This will start the entire homelab!**\n\n"
                f"**Current status:**\n"
                f"- Online: {', '.join(online_nodes) if online_nodes else 'None'}\n"
                f"- Offline: {', '.join(offline_nodes) if offline_nodes else 'None'}\n\n"
                "**Startup order:**\n"
                "1. Send Wake-on-LAN to offline nodes\n"
                "2. Wait for nodes to come online (up to 5 min each)\n"
                "3. Start all LXC containers (Pi-hole first)\n"
                "4. Start all VMs\n\n"
                f":hourglass: This may take 5-10 minutes.{warning_text}"
            ),
            callback=self._perform_startup_all
        )

    # ==================== Confirmation Pattern ====================

    async def _confirm_and_execute(
        self,
        interaction: discord.Interaction,
        operation: str,
        title: str,
        description: str,
        callback
    ):
        """Show confirmation embed and wait for reaction approval."""
        embed = discord.Embed(
            title=title,
            description=description,
            color=discord.Color.orange()
        )
        embed.set_footer(
            text=f"React with {CONFIRM_EMOJI} to confirm or {CANCEL_EMOJI} to cancel | Expires in 60s"
        )

        msg = await interaction.followup.send(embed=embed, wait=True)

        await msg.add_reaction(CONFIRM_EMOJI)
        await msg.add_reaction(CANCEL_EMOJI)

        # Store pending confirmation
        self._pending_confirmations[msg.id] = {
            'operation': operation,
            'user_id': interaction.user.id,
            'callback': callback,
            'message': msg,
            'channel': interaction.channel,
            'expires': time.time() + 60,
        }

    @commands.Cog.listener()
    async def on_raw_reaction_add(self, payload: discord.RawReactionActionEvent):
        """Handle confirmation reactions."""
        # Ignore bot's own reactions
        if payload.user_id == self.bot.user.id:
            return

        # Check if this is a pending confirmation
        if payload.message_id not in self._pending_confirmations:
            return

        info = self._pending_confirmations[payload.message_id]
        emoji = str(payload.emoji)

        # Only original user can confirm
        if payload.user_id != info['user_id']:
            return

        # Check expiration
        if time.time() > info['expires']:
            del self._pending_confirmations[payload.message_id]
            message = info['message']
            embed = discord.Embed(
                title=":clock1: Operation Expired",
                description="Confirmation timed out. Please run the command again.",
                color=discord.Color.grey()
            )
            await message.edit(embed=embed)
            await message.clear_reactions()
            return

        message = info['message']

        if emoji == CONFIRM_EMOJI:
            # Execute the operation
            del self._pending_confirmations[payload.message_id]
            await message.clear_reactions()
            await info['callback'](message, info['channel'])

        elif emoji == CANCEL_EMOJI:
            # Cancel
            del self._pending_confirmations[payload.message_id]
            embed = discord.Embed(
                title=":x: Operation Cancelled",
                description="Power operation was cancelled by user.",
                color=discord.Color.grey()
            )
            await message.edit(embed=embed)
            await message.clear_reactions()

    # ==================== Shutdown Implementation ====================

    async def _perform_shutdown_all(self, message: discord.Message, channel):
        """Execute full cluster shutdown."""
        report = PowerOperationReport(operation='shutdown')

        # Update embed to show progress
        embed = discord.Embed(
            title=":hourglass: Shutting Down Cluster...",
            description="Gracefully stopping all infrastructure...",
            color=discord.Color.blue()
        )
        embed.add_field(name="Phase", value=":computer: Preparing...", inline=False)
        await message.edit(embed=embed)

        # Phase 1: Stop VMs (in reverse node order - services on node02 first)
        await self._shutdown_vms(message, embed, report, exclude_node_ips=[])

        # Phase 2: Stop LXCs
        await self._shutdown_lxcs(message, embed, report, exclude_ctids=[])

        # Phase 3: Shutdown nodes
        await self._shutdown_nodes(message, embed, report, exclude_node_ips=[])

        # Final report
        await message.edit(embed=report.to_embed())

    async def _perform_shutdown_nodns(self, message: discord.Message, channel):
        """Execute partial shutdown keeping Pi-hole and node01."""
        report = PowerOperationReport(operation='shutdown')

        # Get Pi-hole info
        pihole_info = CRITICAL_LXCS.get('pi-hole')
        pihole_node_ip = pihole_info[0] if pihole_info else None
        pihole_ctid = pihole_info[1] if pihole_info else None

        # Find which node to keep
        kept_node = None
        for name, ip in PROXMOX_NODES.items():
            if ip == pihole_node_ip:
                kept_node = name
                break

        embed = discord.Embed(
            title=":hourglass: Shutting Down (Keeping DNS)...",
            description="Gracefully stopping infrastructure (except Pi-hole)...",
            color=discord.Color.blue()
        )
        embed.add_field(name="Phase", value=":computer: Preparing...", inline=False)
        await message.edit(embed=embed)

        # Phase 1: Stop VMs on all nodes except Pi-hole's node
        # Actually, we stop VMs on ALL nodes since Pi-hole is an LXC, not a VM
        await self._shutdown_vms(message, embed, report, exclude_node_ips=[])

        # Phase 2: Stop LXCs except Pi-hole
        await self._shutdown_lxcs(message, embed, report, exclude_ctids=[pihole_ctid])
        report.lxcs_skipped.append(f"pi-hole (CT{pihole_ctid})")

        # Phase 3: Shutdown nodes except Pi-hole's host
        await self._shutdown_nodes(message, embed, report, exclude_node_ips=[pihole_node_ip])
        report.nodes_skipped.append(f"{kept_node} (Pi-hole host)")

        # Final report
        await message.edit(embed=report.to_embed())

    async def _shutdown_vms(
        self,
        message: discord.Message,
        embed: discord.Embed,
        report: PowerOperationReport,
        exclude_node_ips: List[str]
    ):
        """Stop all VMs in proper order."""
        for node_name in NODE_SHUTDOWN_ORDER:
            node_ip = PROXMOX_NODES.get(node_name)
            if not node_ip or node_ip in exclude_node_ips:
                continue

            # Check if node is online
            if not await self.ssh.pve_is_node_online(node_ip):
                logger.info(f"Node {node_name} is offline, skipping VM shutdown")
                continue

            embed.set_field_at(
                0, name="Phase",
                value=f":computer: Stopping VMs on {node_name}...",
                inline=False
            )
            await message.edit(embed=embed)

            # Get running VMs
            vms = await self.ssh.pve_get_running_vms(node_ip)

            for vm in vms:
                vmid = vm['vmid']
                name = vm['name']
                report.vms_total += 1

                logger.info(f"Stopping VM {name} ({vmid}) on {node_name}")
                result = await self.ssh.pve_stop_vm(node_ip, vmid)

                if result.success:
                    report.vms_success += 1
                    logger.info(f"VM {name} stopped successfully")
                else:
                    report.vms_failures.append(f"{name} ({vmid})")
                    logger.error(f"Failed to stop VM {name}: {result.stderr}")

                # Small delay between VM stops
                await asyncio.sleep(1)

    async def _shutdown_lxcs(
        self,
        message: discord.Message,
        embed: discord.Embed,
        report: PowerOperationReport,
        exclude_ctids: List[int]
    ):
        """Stop all LXC containers in proper order."""
        embed.set_field_at(
            0, name="Phase",
            value=":package: Stopping LXC containers...",
            inline=False
        )
        await message.edit(embed=embed)

        for node_name in NODE_SHUTDOWN_ORDER:
            node_ip = PROXMOX_NODES.get(node_name)
            if not node_ip:
                continue

            # Check if node is online
            if not await self.ssh.pve_is_node_online(node_ip):
                logger.info(f"Node {node_name} is offline, skipping LXC shutdown")
                continue

            # Get running LXCs
            lxcs = await self.ssh.pve_get_running_lxcs(node_ip)

            for lxc in lxcs:
                ctid = lxc['ctid']
                name = lxc['name']

                if ctid in exclude_ctids:
                    logger.info(f"Skipping LXC {name} ({ctid}) - excluded")
                    continue

                report.lxcs_total += 1

                logger.info(f"Stopping LXC {name} ({ctid}) on {node_name}")
                result = await self.ssh.pve_stop_lxc(node_ip, ctid)

                if result.success:
                    report.lxcs_success += 1
                    logger.info(f"LXC {name} stopped successfully")
                else:
                    report.lxcs_failures.append(f"{name} ({ctid})")
                    logger.error(f"Failed to stop LXC {name}: {result.stderr}")

                await asyncio.sleep(1)

    async def _shutdown_nodes(
        self,
        message: discord.Message,
        embed: discord.Embed,
        report: PowerOperationReport,
        exclude_node_ips: List[str]
    ):
        """Shutdown Proxmox nodes in proper order."""
        for node_name in NODE_SHUTDOWN_ORDER:
            node_ip = PROXMOX_NODES.get(node_name)
            if not node_ip or node_ip in exclude_node_ips:
                continue

            # Check if node is online
            if not await self.ssh.pve_is_node_online(node_ip):
                logger.info(f"Node {node_name} is already offline")
                continue

            report.nodes_total += 1
            embed.set_field_at(
                0, name="Phase",
                value=f":desktop_computer: Shutting down {node_name}...",
                inline=False
            )
            await message.edit(embed=embed)

            logger.info(f"Shutting down node {node_name} ({node_ip})")
            result = await self.ssh.pve_shutdown_node(node_ip)

            # Connection reset is expected during shutdown
            if result.success or 'Connection reset' in result.stderr or 'closed' in result.stderr.lower():
                report.nodes_success += 1
                logger.info(f"Node {node_name} shutdown initiated")
            else:
                report.nodes_failures.append(node_name)
                logger.error(f"Failed to shutdown node {node_name}: {result.stderr}")

            # Wait between node shutdowns
            await asyncio.sleep(5)

    # ==================== Startup Implementation ====================

    async def _perform_startup_all(self, message: discord.Message, channel):
        """Execute full cluster startup."""
        report = PowerOperationReport(operation='startup')

        embed = discord.Embed(
            title=":hourglass: Starting Cluster...",
            description="Waking nodes and starting infrastructure...",
            color=discord.Color.blue()
        )
        embed.add_field(name="Phase", value=":satellite: Preparing...", inline=False)
        await message.edit(embed=embed)

        # Phase 1: Wake nodes via WoL
        await self._wake_nodes(message, embed, report)

        # Phase 2: Wait for nodes to come online
        await self._wait_for_nodes(message, embed, report)

        # Phase 3: Start LXCs (Pi-hole first for DNS)
        await self._start_lxcs(message, embed, report)

        # Phase 4: Start VMs
        await self._start_vms(message, embed, report)

        # Final report
        await message.edit(embed=report.to_embed())

    async def _wake_nodes(
        self,
        message: discord.Message,
        embed: discord.Embed,
        report: PowerOperationReport
    ):
        """Send WoL packets to all offline nodes."""
        for node_name in NODE_STARTUP_ORDER:
            node_ip = PROXMOX_NODES.get(node_name)
            if not node_ip:
                continue

            # Check if already online
            if await self.ssh.pve_is_node_online(node_ip):
                logger.info(f"Node {node_name} is already online")
                continue

            mac = WOL_MAC_ADDRESSES.get(node_name)
            if not mac or mac == 'TBD':
                logger.warning(f"No MAC address configured for {node_name}")
                report.nodes_failures.append(f"{node_name} (no MAC)")
                continue

            report.nodes_total += 1
            embed.set_field_at(
                0, name="Phase",
                value=f":satellite: Sending WoL to {node_name}...",
                inline=False
            )
            await message.edit(embed=embed)

            logger.info(f"Sending WoL to {node_name} ({mac})")
            result = await self.ssh.send_wol(mac, WOL_BROADCAST)

            if not result.success:
                logger.error(f"Failed to send WoL to {node_name}: {result.stderr}")
                # Don't count as failure yet - we'll check if it comes online

            # Small delay between WoL packets
            await asyncio.sleep(1)

    async def _wait_for_nodes(
        self,
        message: discord.Message,
        embed: discord.Embed,
        report: PowerOperationReport
    ):
        """Wait for all nodes to come online."""
        for node_name in NODE_STARTUP_ORDER:
            node_ip = PROXMOX_NODES.get(node_name)
            if not node_ip:
                continue

            # Check if already online
            if await self.ssh.pve_is_node_online(node_ip):
                if report.nodes_total > 0:
                    # Only count if we tried to wake it
                    pass
                else:
                    report.nodes_total += 1
                report.nodes_success += 1
                logger.info(f"Node {node_name} is online")
                continue

            # Skip if we didn't try to wake it (no MAC)
            mac = WOL_MAC_ADDRESSES.get(node_name)
            if not mac or mac == 'TBD':
                continue

            embed.set_field_at(
                0, name="Phase",
                value=f":hourglass: Waiting for {node_name} to come online...",
                inline=False
            )
            await message.edit(embed=embed)

            is_online = await self.ssh.wait_for_node_online(node_ip, timeout=300)
            if is_online:
                report.nodes_success += 1
            else:
                report.nodes_failures.append(f"{node_name} (timeout)")

    async def _start_lxcs(
        self,
        message: discord.Message,
        embed: discord.Embed,
        report: PowerOperationReport
    ):
        """Start LXC containers in priority order."""
        embed.set_field_at(
            0, name="Phase",
            value=":package: Starting LXC containers...",
            inline=False
        )
        await message.edit(embed=embed)

        # Start in priority order
        for name, node_ip, ctid in LXC_STARTUP_ORDER:
            # Check if node is online
            if not await self.ssh.pve_is_node_online(node_ip):
                logger.warning(f"Node for LXC {name} is offline, skipping")
                report.lxcs_failures.append(f"{name} (node offline)")
                continue

            # Check if already running
            if await self.ssh.lxc_is_running(node_ip, ctid):
                logger.info(f"LXC {name} is already running")
                continue

            report.lxcs_total += 1

            logger.info(f"Starting LXC {name} ({ctid})")
            result = await self.ssh.pve_start_lxc(node_ip, ctid)

            if result.success:
                report.lxcs_success += 1
                logger.info(f"LXC {name} started successfully")
            else:
                report.lxcs_failures.append(f"{name} ({ctid})")
                logger.error(f"Failed to start LXC {name}: {result.stderr}")

            # Brief delay to allow service initialization
            await asyncio.sleep(3)

    async def _start_vms(
        self,
        message: discord.Message,
        embed: discord.Embed,
        report: PowerOperationReport
    ):
        """Start all VMs in proper order."""
        for node_name in NODE_STARTUP_ORDER:
            node_ip = PROXMOX_NODES.get(node_name)
            if not node_ip:
                continue

            # Check if node is online
            if not await self.ssh.pve_is_node_online(node_ip):
                logger.warning(f"Node {node_name} is offline, skipping VM startup")
                continue

            embed.set_field_at(
                0, name="Phase",
                value=f":computer: Starting VMs on {node_name}...",
                inline=False
            )
            await message.edit(embed=embed)

            # Get all VMs (including stopped)
            vms = await self.ssh.pve_get_all_vms(node_ip)

            for vm in vms:
                vmid = vm['vmid']
                name = vm['name']
                status = vm['status']

                if status == 'running':
                    logger.info(f"VM {name} is already running")
                    continue

                report.vms_total += 1

                logger.info(f"Starting VM {name} ({vmid}) on {node_name}")
                result = await self.ssh.pve_start_vm(node_ip, vmid)

                if result.success:
                    report.vms_success += 1
                    logger.info(f"VM {name} started successfully")
                else:
                    report.vms_failures.append(f"{name} ({vmid})")
                    logger.error(f"Failed to start VM {name}: {result.stderr}")

                # Brief delay between VM starts
                await asyncio.sleep(2)


async def setup(bot: 'SentinelBot'):
    """Load the Power cog."""
    await bot.add_cog(PowerCog(bot))

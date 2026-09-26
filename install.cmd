```bat
@echo off
setlocal EnableExtensions
title BoxyyBot Complete Installer

echo.
echo ============================================================
echo                    BOXXYYBOT INSTALLER
echo ============================================================
echo.

set "PROJECT=%USERPROFILE%\Desktop\boxyybot"

if not exist "%PROJECT%" (
    echo [1/10] Projectmap maken...
    mkdir "%PROJECT%"
) else (
    echo [1/10] Projectmap bestaat al.
)

cd /d "%PROJECT%"

echo.
echo [2/10] Python controleren...
py --version

if errorlevel 1 (
    echo.
    echo ============================================================
    echo FOUT: Python is niet gevonden.
    echo.
    echo Installeer Python 3.11 of nieuwer en probeer opnieuw.
    echo ============================================================
    pause
    exit /b 1
)

echo.
echo [3/10] Virtual environment maken...

if not exist ".venv" (
    py -m venv .venv
)

if not exist ".venv\Scripts\python.exe" (
    echo.
    echo FOUT: Virtual environment kon niet worden gemaakt.
    pause
    exit /b 1
)

echo.
echo [4/10] Packages installeren...

".venv\Scripts\python.exe" -m pip install --upgrade pip
".venv\Scripts\python.exe" -m pip install --upgrade discord.py python-dotenv

if errorlevel 1 (
    echo.
    echo ============================================================
    echo FOUT: Packages konden niet worden geinstalleerd.
    echo ============================================================
    pause
    exit /b 1
)

echo.
echo [5/10] bot.py maken...

".venv\Scripts\python.exe" -c "from pathlib import Path; Path('bot.py').write_text(r'''import os
import asyncio
from datetime import datetime

import discord
from discord.ext import commands
from discord.ui import View
from dotenv import load_dotenv


# ============================================================
# CONFIG
# ============================================================

load_dotenv()

BOT_TOKEN = os.getenv('DISCORD_BOT_TOKEN', '').strip()

PREFIX = '!'

MEMBERS_ROLE_NAME = 'Members'
BRONZE_ROLE_NAME = 'Free Bronze'
BRONZE_STATUS_TEXT = 'Free Bronze'


# ============================================================
# INTENTS
# ============================================================

intents = discord.Intents.default()

intents.message_content = True
intents.members = True
intents.presences = True


# ============================================================
# ROLE FUNCTIONS
# ============================================================

async def get_or_create_role(guild, role_name):

    role = discord.utils.get(
        guild.roles,
        name=role_name
    )

    if role is not None:
        return role

    try:

        role = await guild.create_role(
            name=role_name,
            reason='BoxyyBot automatic role setup'
        )

        print(f'[ROLE] Aangemaakt: {role_name}')

        return role

    except discord.Forbidden:

        print(
            f'[ROLE ERROR] Geen rechten om role '
            f'{role_name} te maken.'
        )

        return None

    except discord.HTTPException as error:

        print(
            f'[ROLE ERROR] {error}'
        )

        return None


def has_free_bronze_status(member):

    if member.status != discord.Status.online:
        return False

    for activity in member.activities:

        if isinstance(activity, discord.CustomActivity):

            status_text = activity.name or ''

            if BRONZE_STATUS_TEXT.lower() in status_text.lower():
                return True

    return False


def is_verified(member):

    role = discord.utils.get(
        member.guild.roles,
        name=MEMBERS_ROLE_NAME
    )

    if role is None:
        return False

    return role in member.roles


# ============================================================
# DELETE MESSAGE AFTER 30 SECONDS
# ============================================================

async def delete_after_30_seconds(message):

    await asyncio.sleep(30)

    try:

        await message.delete()

    except discord.NotFound:
        pass

    except discord.Forbidden:
        pass

    except discord.HTTPException:
        pass


# ============================================================
# UPDATE ROLES
# ============================================================

async def update_member_roles(member):

    members_role = await get_or_create_role(
        member.guild,
        MEMBERS_ROLE_NAME
    )

    bronze_role = await get_or_create_role(
        member.guild,
        BRONZE_ROLE_NAME
    )

    if members_role is None:

        return {
            'success': False,
            'bronze': False
        }

    try:

        if members_role not in member.roles:

            await member.add_roles(
                members_role,
                reason='BoxyyBot verification'
            )

    except discord.Forbidden:

        print(
            '[VERIFY ERROR] Bot heeft geen Manage Roles.'
        )

        return {
            'success': False,
            'bronze': False
        }

    except discord.HTTPException as error:

        print(
            f'[VERIFY ERROR] {error}'
        )

        return {
            'success': False,
            'bronze': False
        }

    bronze_active = has_free_bronze_status(member)

    if bronze_role is not None:

        try:

            if bronze_active:

                if bronze_role not in member.roles:

                    await member.add_roles(
                        bronze_role,
                        reason='Free Bronze status detected'
                    )

            else:

                if bronze_role in member.roles:

                    await member.remove_roles(
                        bronze_role,
                        reason='Free Bronze status removed'
                    )

        except discord.Forbidden:

            print(
                '[BRONZE ERROR] Bot heeft geen rolrechten.'
            )

        except discord.HTTPException as error:

            print(
                f'[BRONZE ERROR] {error}'
            )

    return {
        'success': True,
        'bronze': bronze_active
    }


# ============================================================
# VERIFY BUTTON
# ============================================================

class VerifyView(View):

    def __init__(self):

        super().__init__(
            timeout=None
        )

    @discord.ui.button(
        label='Verify',
        style=discord.ButtonStyle.success,
        emoji='✅',
        custom_id='boxyybot_verify'
    )
    async def verify_button(
        self,
        interaction,
        button
    ):

        if interaction.guild is None:

            await interaction.response.send_message(
                '❌ Gebruik deze knop in een Discord-server.',
                ephemeral=True
            )

            return

        member = interaction.user

        if not isinstance(member, discord.Member):

            await interaction.response.send_message(
                '❌ Ik kan jouw serverprofiel niet vinden.',
                ephemeral=True
            )

            return

        result = await update_member_roles(
            member
        )

        if not result['success']:

            await interaction.response.send_message(
                '❌ Verification mislukt.\n\n'
                'Controleer of BoxyyBot **Manage Roles** '
                'heeft en of de bot-role boven **Members** '
                'en **Free Bronze** staat.',
                ephemeral=True
            )

            return

        if result['bronze']:

            message_text = (
                f'{member.mention}\n\n'
                '╭──────────────────────────────╮\n'
                '     ✅ **VERIFICATION COMPLETED**\n'
                '╰──────────────────────────────╯\n\n'
                '👥 **Members** is toegevoegd.\n'
                '🏅 **Free Bronze** is ook toegevoegd.\n\n'
                'Je bent online en gebruikt `Free Bronze` '
                'als Custom Status.'
            )

        else:

            message_text = (
                f'{member.mention}\n\n'
                '╭──────────────────────────────╮\n'
                '     ✅ **VERIFICATION COMPLETED**\n'
                '╰──────────────────────────────╯\n\n'
                '👥 **Members** is toegevoegd.\n\n'
                '🏅 **Free Bronze**\n'
                'Zet `Free Bronze` in je Custom Status '
                'en blijf online om Free Bronze te krijgen.'
            )

        channel = interaction.channel

        if channel is not None:

            try:

                message = await channel.send(
                    message_text,
                    allowed_mentions=discord.AllowedMentions(
                        users=True
                    )
                )

                asyncio.create_task(
                    delete_after_30_seconds(
                        message
                    )
                )

            except discord.Forbidden:

                print(
                    '[CHANNEL ERROR] Geen rechten om '
                    'berichten te sturen.'
                )

            except discord.HTTPException as error:

                print(
                    f'[CHANNEL ERROR] {error}'
                )

        await interaction.response.send_message(
            '✅ **Verification succesvol!**\n'
            'Je hebt de **Members** role gekregen.',
            ephemeral=True
        )


# ============================================================
# BOT
# ============================================================

class BoxyyBot(commands.Bot):

    def __init__(self):

        super().__init__(
            command_prefix=PREFIX,
            intents=intents,
            help_command=None
        )

    async def setup_hook(self):

        self.add_view(
            VerifyView()
        )

        print(
            '[BOT] Persistent Verify button geladen.'
        )


bot = BoxyyBot()


# ============================================================
# READY
# ============================================================

@bot.event
async def on_ready():

    print()
    print('=' * 60)
    print('                    BOXXYYBOT')
    print('=' * 60)
    print(f'Bot          : {bot.user}')
    print(f'Servers      : {len(bot.guilds)}')
    print('Verification : ON')
    print('Channel Ping : ON')
    print('Auto Delete  : 30 seconds')
    print('Free Bronze  : ON')
    print('Active Check : ON')
    print('=' * 60)
    print()


# ============================================================
# !VERIFY
# ============================================================

@bot.command(name='verify')
async def verify(ctx):

    embed = discord.Embed(
        title='🛡️ BOXXYYBOT • SERVER VERIFICATION',
        description=(
            'Welkom bij de server verification.\n\n'

            '🔐 **Waarom verification?**\n'
            'Verification helpt de server om communityleden '
            'te herkennen en functies gecontroleerd beschikbaar '
            'te maken.\n\n'

            '👥 **Wat krijg je?**\n'
            'Na verification ontvang je automatisch de '
            '**Members** role.\n\n'

            '🏅 **Free Bronze**\n'
            'Zet `Free Bronze` in je Custom Status en blijf '
            'online. BoxyyBot controleert dit automatisch.\n\n'

            '📡 **Active Check**\n'
            'Met `!activecheck` kun je de huidige activiteit '
            'van de server controleren.\n\n'

            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n'

            'Klik hieronder op **✅ Verify** om verder te gaan.'
        ),
        color=discord.Color.blurple(),
        timestamp=datetime.utcnow()
    )

    embed.add_field(
        name='🟢 Verification',
        value='Automatisch',
        inline=True
    )

    embed.add_field(
        name='🏅 Bronze',
        value='Custom Status + Online',
        inline=True
    )

    embed.add_field(
        name='📡 Active Check',
        value='Beschikbaar',
        inline=True
    )

    embed.set_footer(
        text='BoxyyBot • Secure Server Verification'
    )

    await ctx.send(
        embed=embed,
        view=VerifyView()
    )


# ============================================================
# !ACTIVECHECK
# ============================================================

@bot.command(name='activecheck')
@commands.guild_only()
async def activecheck(ctx):

    online = 0
    verified = 0
    bronze = 0

    for member in ctx.guild.members:

        if member.bot:
            continue

        if member.status == discord.Status.online:
            online += 1

        if is_verified(member):
            verified += 1

        if (
            is_verified(member)
            and has_free_bronze_status(member)
        ):
            bronze += 1

    embed = discord.Embed(
        title='📡 BOXXYYBOT • ACTIVE CHECK',
        description=(
            'Hieronder staat de huidige activity-check '
            'van deze server.\n\n'

            'De bot controleert online presence, '
            'verification en Free Bronze.'
        ),
        color=discord.Color.green(),
        timestamp=datetime.utcnow()
    )

    embed.add_field(
        name='🟢 Online',
        value=f'**{online}** leden',
        inline=True
    )

    embed.add_field(
        name='👥 Verified',
        value=f'**{verified}** leden',
        inline=True
    )

    embed.add_field(
        name='🏅 Bronze Active',
        value=f'**{bronze}** leden',
        inline=True
    )

    embed.add_field(
        name='ℹ️ Uitleg',
        value=(
            '• Online = momenteel online.\n'
            '• Verified = heeft Members-role.\n'
            '• Bronze Active = verified + online + '
            '`Free Bronze` Custom Status.'
        ),
        inline=False
    )

    embed.set_footer(
        text='BoxyyBot • Active Check'
    )

    await ctx.send(
        embed=embed
    )


# ============================================================
# !STATUS
# ============================================================

@bot.command(name='status')
async def status_command(ctx):

    ping = round(
        bot.latency * 1000
    )

    embed = discord.Embed(
        title='🟢 BOXXYYBOT • SYSTEM STATUS',
        color=discord.Color.green()
    )

    embed.add_field(
        name='🤖 Bot',
        value='Online',
        inline=True
    )

    embed.add_field(
        name='📡 Ping',
        value=f'{ping}ms',
        inline=True
    )

    embed.add_field(
        name='🌐 Servers',
        value=str(len(bot.guilds)),
        inline=True
    )

    embed.add_field(
        name='🛡️ Verification',
        value='Active',
        inline=True
    )

    embed.add_field(
        name='🏅 Free Bronze',
        value='Active',
        inline=True
    )

    embed.add_field(
        name='📡 Active Check',
        value='Available',
        inline=True
    )

    await ctx.send(
        embed=embed
    )


# ============================================================
# !MEMBERS
# ============================================================

@bot.command(name='members')
@commands.guild_only()
async def members_command(ctx):

    await ctx.send(
        f'👥 Deze server heeft '
        f'**{ctx.guild.member_count}** leden.'
    )


# ============================================================
# !HELP
# ============================================================

@bot.command(name='help')
async def help_command(ctx):

    embed = discord.Embed(
        title='🦜 BOXXYYBOT • COMMAND CENTER',
        description=(
            '`!verify` — Verification panel\n'
            '`!activecheck` — Active members check\n'
            '`!status` — Bot status\n'
            '`!members` — Server members\n'
            '`!help` — Command overzicht'
        ),
        color=discord.Color.blurple()
    )

    embed.set_footer(
        text='BoxyyBot • Command Center'
    )

    await ctx.send(
        embed=embed
    )


# ============================================================
# AUTOMATIC FREE BRONZE
# ============================================================

@bot.event
async def on_presence_update(
    before,
    after
):

    if (
        before.status == after.status
        and before.activities == after.activities
    ):
        return

    members_role = discord.utils.get(
        after.guild.roles,
        name=MEMBERS_ROLE_NAME
    )

    bronze_role = discord.utils.get(
        after.guild.roles,
        name=BRONZE_ROLE_NAME
    )

    if members_role is None:
        return

    if bronze_role is None:
        return

    if members_role not in after.roles:
        return

    bronze_active = has_free_bronze_status(
        after
    )

    try:

        if bronze_active:

            if bronze_role not in after.roles:

                await after.add_roles(
                    bronze_role,
                    reason='Free Bronze status detected'
                )

                print(
                    f'[BRONZE] Added: {after}'
                )

        else:

            if bronze_role in after.roles:

                await after.remove_roles(
                    bronze_role,
                    reason='Free Bronze status removed'
                )

                print(
                    f'[BRONZE] Removed: {after}'
                )

    except discord.Forbidden:

        print(
            '[BRONZE ERROR] Geen rolrechten.'
        )

    except discord.HTTPException as error:

        print(
            f'[BRONZE ERROR] {error}'
        )


# ============================================================
# COMMAND ERRORS
# ============================================================

@bot.event
async def on_command_error(
    ctx,
    error
):

    if isinstance(
        error,
        commands.CommandNotFound
    ):
        return

    print(
        f'[COMMAND ERROR] '
        f'{type(error).__name__}: {error}'
    )


# ============================================================
# START BOT
# ============================================================

if not BOT_TOKEN:

    print()
    print('=' * 60)
    print('ERROR: DISCORD_BOT_TOKEN ONTBREEKT')
    print('=' * 60)
    print()
    print(
        'Open .env en vul je normale Discord bot token in.'
    )
    print()

    raise SystemExit(1)


print(
    '🚀 BoxyyBot wordt gestart...'
)

try:

    bot.run(
        BOT_TOKEN
    )

except discord.LoginFailure:

    print(
        '❌ Discord login mislukt. Controleer je .env.'
    )

except Exception as error:

    print(
        f'❌ Bot error: '
        f'{type(error).__name__}: {error}'
    )
''', encoding='utf-8')"

if errorlevel 1 (
    echo.
    echo FOUT: bot.py kon niet worden gemaakt.
    pause
    exit /b 1
)

echo.
echo [6/10] .env maken...

if not exist ".env" (
    >".env" echo DISCORD_BOT_TOKEN=
) else (
    echo .env bestaat al - niet overschreven.
)

echo.
echo [7/10] auths.txt maken...

if not exist "auths.txt" (
    >"auths.txt" echo # DEMO ONLY
    >>"auths.txt" echo # Gebruik hier GEEN echte Discord tokens.
    >>"auths.txt" echo # Deze file is alleen aanwezig voor lokale projectcompatibiliteit.
    >>"auths.txt" echo DEMO_ONLY_member_001_a8f31
    >>"auths.txt" echo DEMO_ONLY_member_002_b71c2
    >>"auths.txt" echo DEMO_ONLY_member_003_c92d4
)

echo.
echo [8/10] config.json maken...

>"config.json" (
    echo {
    echo   "prefix": "!",
    echo   "members_role": "Members",
    echo   "bronze_role": "Free Bronze",
    echo   "bronze_status": "Free Bronze",
    echo   "verification_message_delete_seconds": 30
    echo }
)

echo.
echo [9/10] START.bat, README en .gitignore maken...

>"START.bat" (
    echo @echo off
    echo title BoxyyBot
    echo cd /d "%%~dp0"
    echo.
    echo if not exist ".venv\Scripts\python.exe" ^(
    echo     echo Virtual environment ontbreekt.
    echo     echo Voer eerst INSTALL.bat uit.
    echo     pause
    echo     exit /b 1
    echo ^)
    echo.
    echo echo ============================================================
    echo echo                     BOXXYYBOT
    echo echo ============================================================
    echo echo.
    echo echo Bot wordt gestart...
    echo echo Stoppen: CTRL+C
    echo echo.
    echo ".venv\Scripts\python.exe" bot.py
    echo.
    echo pause
)

>"README.txt" (
    echo ============================================================
    echo                         BOXXYYBOT
    echo ============================================================
    echo.
    echo INSTALLATIE
    echo.
    echo 1. Vul je Discord bot token in in .env
    echo.
    echo    DISCORD_BOT_TOKEN=JOUW_BOT_TOKEN
    echo.
    echo 2. Zet de benodigde Discord Developer Portal intents aan:
    echo.
    echo    - Message Content Intent
    echo    - Server Members Intent
    echo    - Presence Intent
    echo.
    echo 3. Geef de bot minimaal:
    echo.
    echo    - View Channels
    echo    - Send Messages
    echo    - Embed Links
    echo    - Manage Roles
    echo.
    echo 4. Zet de hoogste bot-role boven:
    echo.
    echo    Members
    echo    Free Bronze
    echo.
    echo COMMANDS
    echo.
    echo    !verify
    echo    !activecheck
    echo    !status
    echo    !members
    echo    !help
    echo.
    echo FREE BRONZE
    echo.
    echo Een verified gebruiker krijgt Free Bronze wanneer:
    echo.
    echo    - de gebruiker online is
    echo    - Custom Status "Free Bronze" bevat
    echo.
    echo De bot controleert dit automatisch wanneer de presence
    echo verandert.
    echo.
    echo VERIFY
    echo.
    echo De Verify-knop geeft de gebruiker de Members-role.
    echo.
    echo Na succesvolle verification:
    echo.
    echo    - de gebruiker wordt in hetzelfde kanaal gepingd
    echo    - de ping wordt na 30 seconden verwijderd
    echo    - de gebruiker krijgt een ephemeral bevestiging
    echo.
    echo VEILIGHEID
    echo.
    echo Deze bot gebruikt alleen de normale Discord bot token
    echo uit .env.
    echo.
    echo Gebruik GEEN echte Discord user tokens of OAuth
    echo access/refresh tokens in auths.txt.
    echo.
)

>".gitignore" (
    echo .venv/
    echo __pycache__/
    echo *.pyc
    echo .env
    echo.
    echo # Discord credentials
    echo *.token
)

echo.
echo [10/10] Syntax controleren...

".venv\Scripts\python.exe" -m py_compile bot.py

if errorlevel 1 (
    echo.
    echo ============================================================
    echo FOUT: bot.py bevat een syntaxfout.
    echo ============================================================
    echo.
    echo De installatie is gestopt.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo                  INSTALLATIE VOLTOOID
echo ============================================================
echo.
echo Project:
echo %PROJECT%
echo.
echo Bestanden:
echo.
echo   bot.py
echo   .env
echo   auths.txt
echo   config.json
echo   START.bat
echo   README.txt
echo   .gitignore
echo   requirements.txt
echo.
echo ============================================================
echo.
echo BELANGRIJK:
echo.
echo 1. Open:
echo    %PROJECT%\.env
echo.
echo 2. Vul in:
echo    DISCORD_BOT_TOKEN=JOUW_BOT_TOKEN
echo.
echo 3. Zet in Discord Developer Portal aan:
echo    - Message Content Intent
echo    - Server Members Intent
echo    - Presence Intent
echo.
echo 4. Geef de bot Manage Roles.
echo.
echo 5. Zet de bot-role boven Members en Free Bronze.
echo.
echo 6. Start daarna:
echo    START.bat
echo.
echo ============================================================
echo.

pause
```

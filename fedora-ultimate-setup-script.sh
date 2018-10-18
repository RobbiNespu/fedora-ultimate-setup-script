#!/bin/bash

#==================================================================================================
#
#         FILE: fedora-ultimate-setup-script.sh
#        USAGE: fedora-ultimate-setup-script.sh
#
#  DESCRIPTION: Post-installation setup script for Fedora 28/29 Workstation
#      WEBSITE: https://www.elsewebdevelopment.com/
#
# REQUIREMENTS: Fresh copy of Fedora 28/29 installed on your computer
#       AUTHOR: David Else
#      COMPANY: Else Web Development
#      VERSION: 2.0
#==================================================================================================

# exit on non-zero exit status, undefined var, and any failure in pipeline
set -euo pipefail

#==================================================================================================
# global Constants
#==================================================================================================
REMOVE_LIST=(gnome-photos gnome-documents rhythmbox cheese)

GREEN=$(tput setaf 2)
BOLD=$(tput bold)
RESET=$(tput sgr0)

GIT_EMAIL='example@example.com'
GIT_USER_NAME='David'

#==================================================================================================
# check dependencies
#==================================================================================================
function check_dependencies() {
    if [[ $(rpm -E %fedora) -lt 28 ]]; then
        echo >&2 "You must install at least ${GREEN}Fedora 28${RESET} to use this script" && exit 1
    fi
}

#==================================================================================================
# create list of packages to install
#==================================================================================================
create_package_list() {
    declare -A packages=(
        ['drivers']='libva-intel-driver fuse-exfat'
        ['multimedia']='gstreamer1-vaapi gstreamer1-libav ffmpeg mpv mkvtoolnix-gui shotwell'
        ['utils']='gnome-tweak-tool tldr whipper keepassx transmission-gtk lshw mediainfo klavaro youtube-dl freetype-freeworld'
        ['gnome_extensions']='gnome-shell-extension-auto-move-windows.noarch gnome-shell-extension-pomodoro gnome-terminal-nautilus'
        ['emulation']='winehq-stable dolphin-emu mame'
        ['audio']='jack-audio-connection-kit'
        ['backup_sync']='borgbackup syncthing'
        ['languages']='java-1.8.0-openjdk'
        ['webdev']='chromium chromium-libs-media-freeworld docker docker-compose nodejs php php-json code zeal ShellCheck'
    )
    for package in "${!packages[@]}"; do
        echo "$package: ${GREEN}${packages[$package]}${RESET}" >&2
        PACKAGES_TO_INSTALL+=(${packages[$package]})
    done
}

#==================================================================================================
# add repositories
#==================================================================================================
add_repositories() {
    sudo dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    if [[ ${PACKAGES_TO_INSTALL[*]} == *'winehq-stable'* ]]; then
        sudo dnf config-manager --add-repo https://dl.winehq.org/wine-builds/fedora/28/winehq.repo
    fi

    if [[ ${PACKAGES_TO_INSTALL[*]} == *'code'* ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    fi
}

#==================================================================================================
# setup desktop
#==================================================================================================
setup_desktop() {
    #==============================================================================================
    # various
    #==============================================================================================
    mkdir "$HOME/sites"
    echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
    touch ~/Templates/empty-file # so you can create new documents from nautilus
    cat >>"$HOME/.bashrc" <<EOL
alias ls="ls -ltha --color --group-directories-first" # l=long listing format, t=sort by modification time (newest first), h=human readable sizes, a=print hidden files
alias tree="tree -Catr --noreport --dirsfirst --filelimit 100" # -C=colorization on, a=print hidden files, t=sort by modification time, r=reversed sort by time (newest first)
EOL

    #==============================================================================================
    # setup pulse audio
    #
    # *pacmd list-sinks | grep sample and see bit-depth available
    # *pulseaudio --dump-re-sample-methods and see re-sampling available
    # *MAKE SURE your interface can handle s32le 32bit rather than the default 16bit
    #==============================================================================================
    sudo sed -i "s/; default-sample-format = s16le/default-sample-format = s32le/g" /etc/pulse/daemon.conf
    sudo sed -i "s/; resample-method = speex-float-1/resample-method = speex-float-10/g" /etc/pulse/daemon.conf
    sudo sed -i "s/; avoid-resampling = false/avoid-resampling = true/g" /etc/pulse/daemon.conf

    #==============================================================================================
    # setup gnome desktop gsettings
    #==============================================================================================
    gsettings set org.gnome.settings-daemon.plugins.media-keys max-screencast-length 0 # Ctrl + Shift + Alt + R to start and stop screencast
    gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
    gsettings set org.gnome.desktop.interface clock-show-date true
    gsettings set org.gnome.desktop.session idle-delay 1200
    gsettings set org.gnome.desktop.input-sources xkb-options "['caps:backspace', 'terminate:ctrl_alt_bksp']"
    gsettings set org.gnome.shell.extensions.auto-move-windows application-list "['org.gnome.Nautilus.desktop:2', 'org.gnome.Terminal.desktop:3', 'code.desktop:1', 'firefox.desktop:1']"
    gsettings set org.gnome.shell enabled-extensions "['pomodoro@arun.codito.in', 'auto-move-windows@gnome-shell-extensions.gcampax.github.com']"
    gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true

}

#==================================================================================================
# setup vscode
#==================================================================================================
setup_vscode() {
    local code_extensions=(ban.spellright bierner.comment-tagged-templates
        dbaeumer.vscode-eslint deerawan.vscode-dash esbenp.prettier-vscode
        foxundermoon.shell-format mkaufman.HTMLHint msjsdiag.debugger-for-chrome
        ritwickdey.LiveServer timonwong.shellcheck WallabyJs.quokka-vscode
        Zignd.html-css-class-completion)
    echo
    for extension in "${code_extensions[@]}"; do
        code --install-extension "$extension"
    done

    cat >"$HOME/.config/Code/User/settings.json" <<EOL
// Place your settings in this file to overwrite the default settings
{
  // VS Code 1.28.0 general settings
  "editor.renderWhitespace": "all",
  "editor.dragAndDrop": false,
  "editor.formatOnSave": true,
  "editor.minimap.enabled": false,
  "editor.detectIndentation": false,
  "editor.showUnused": false,
  "workbench.activityBar.visible": false,
  "window.menuBarVisibility": "toggle",
  "window.titleBarStyle": "custom",
  "zenMode.fullScreen": false,
  "zenMode.centerLayout": false,
  "zenMode.restore": true,
  "telemetry.enableTelemetry": false,
  "git.autofetch": true,
  "git.enableSmartCommit": true,
  "git.decorations.enabled": false,
  "php.validate.executablePath": "/usr/bin/php",
  "extensions.showRecommendationsOnlyOnDemand": true,
  "[javascript]": {
    "editor.tabSize": 2
  },
  "[json]": {
    "editor.tabSize": 2
  },
  "[css]": {
    "editor.tabSize": 2
  },
  "[html]": {
    "editor.tabSize": 2
  },
  // Shell Format extension
  "shellformat.flag": "-i 4",
  // Live Server extension
  "liveServer.settings.donotShowInfoMsg": true,
  "liveServer.settings.ChromeDebuggingAttachment": true,
  "liveServer.settings.AdvanceCustomBrowserCmdLine": "/usr/bin/chromium-browser --remote-debugging-port=9222",
  // Spell Right extension
  "spellright.language": "English (British)",
  // Prettier formatting extension
  "prettier.singleQuote": true,
  "prettier.trailingComma": "all",
  // HTML formatting
  "html.format.endWithNewline": true,
  "html.format.wrapLineLength": 80,
  "workbench.statusBar.feedback.visible": false,
  "spellright.documentTypes": ["markdown", "latex", "plaintext"],
  // Various
  "css.lint.zeroUnits": "warning",
  "css.lint.important": "warning",
  "css.lint.universalSelector": "warning",
  "npm.enableScriptExplorer": true,
  "explorer.decorations.colors": false,
  "javascript.updateImportsOnFileMove.enabled": "always",
  "javascript.preferences.quoteStyle": "single",
  "html-css-class-completion.enableEmmetSupport": true,
  "eslint.run": "onSave",
  "json.format.enable": false,
  "editor.lineNumbers": "off",
  "search.followSymlinks": false
}
EOL
}

#==================================================================================================
# setup jack
#==================================================================================================
setup_jack() {
    echo
    sudo usermod -a -G jackuser "$USERNAME" # Add current user to jackuser group
    sudo tee /etc/security/limits.d/95-jack.conf <<EOL
# Default limits for users of jack-audio-connection-kit

@jackuser - rtprio 98
@jackuser - memlock unlimited

@pulse-rt - rtprio 20
@pulse-rt - nice -20
EOL
}

#==================================================================================================
# setup shfmt *binary must be in current directory
#==================================================================================================
function setup_shfmt() {
    if [[ -f ./shfmt_v2.3.0_linux_amd64 ]]; then
        # Latest binary available from https://github.com/mvdan/sh/releases
        chmod +x shfmt_v2.3.0_linux_amd64
        sudo mv shfmt_v2.3.0_linux_amd64 /usr/local/bin/shfmt
    fi
}

#==================================================================================================
# setup git
#==================================================================================================
setup_git() {
    if [[ -z $(git config --get user.name) ]]; then
        git config --global user.name $GIT_USER_NAME
        echo "No global git user name was set, I have set it to ${BOLD}$GIT_USER_NAME${RESET}"
    fi
    if [[ -z $(git config --get user.email) ]]; then
        git config --global user.email $GIT_EMAIL
        echo "No global git email was set, I have set it to ${BOLD}$GIT_EMAIL${RESET}"
    fi
}

#==================================================================================================
# setup subpixel hinting for freetype-freeworld
#==================================================================================================
setup_freetype_freeworld() {
    gsettings set org.gnome.settings-daemon.plugins.xsettings hinting slight
    gsettings set org.gnome.settings-daemon.plugins.xsettings antialiasing rgba
    echo "Xft.lcdfilter: lcddefault" >>"$HOME/.Xresources"
}

#==================================================================================================
# main
#==================================================================================================
main() {
    local hostname
    clear
    check_dependencies
    echo "${BOLD}Programs to add:${RESET}"
    echo
    create_package_list
    echo
    echo "${BOLD}Programs to remove:${RESET}"
    echo
    echo "${GREEN}${REMOVE_LIST[*]}${RESET}"
    echo
    read -rp "What is this computer's name (hostname)? " hostname
    hostnamectl set-hostname "$hostname"
    echo
    add_repositories
    echo "Updating Fedora and installing packages..."
    sudo dnf remove "${REMOVE_LIST[@]}"
    sudo dnf -y --refresh upgrade
    sudo dnf -y install "${PACKAGES_TO_INSTALL[@]}"
    setup_desktop
    setup_git
    if [[ ${PACKAGES_TO_INSTALL[*]} == *'code'* ]]; then
        setup_vscode
        setup_shfmt
    fi
    if [[ ${PACKAGES_TO_INSTALL[*]} == *'jack-audio'* ]]; then
        setup_jack
    fi
    if [[ ${PACKAGES_TO_INSTALL[*]} == *'freetype-freeworld'* ]]; then
        setup_freetype_freeworld
    fi
    cat <<EOL
After installation you may perform these additional tasks:

- Run mpv once then:
 'printf "profile=gpu-hq\nfullscreen=yes\n" | tee "$HOME/.config/mpv/mpv.conf"' or:
  profile=gpu-hq\nfullscreen=yes\nvideo-sync=display-resample\ninterpolation=yes\ntscale=oversample\n
- Install 'Hide Top Bar' extension from Gnome software
- Firefox "about:support" what is compositor? If 'basic' open "about:config"
  find "layers.acceleration.force-enabled" and switch to true, this will
  force OpenGL acceleration
- Update .bash_profile with
  'PATH=$PATH:$HOME/.local/bin:$HOME/bin:$HOME/Documents/scripts:$HOME/Documents/scripts/borg-backup'
- Install HTTPS everywhere, privacy badger, ublock origin in Firefox/Chromium
- Consider "sudo dnf install kernel-tools", "sudo cpupower frequency-set --governor performance"
- Files > preferences > views > sort folders before files
- Change shotwell import directory format to %Y/%m + rename lower case, import photos from external drive
- UMS > un-tick general config > enable external network + check force network on interface correct network (wlp2s0)
- Allow virtual machines that use fusefs to intall properly with SELinux # sudo setsebool -P virt_use_fusefs 1
- make symbolic links to media ln -s /run/media/david/WD-Red-2TB/Media/Audio ~/Music
  =================
  REBOOTING NOW!!!!
  shutdown -r
  =================
EOL
}
main

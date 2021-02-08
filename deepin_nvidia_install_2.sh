#!/bin/bash
# 请将这个文件的文件名字命名为 deepin_nvidia_install_2.sh
# 安装说明
# 重要！！！！首先需要通过tty非图形界面执行代码，而非在平常的图形界面运行代码
# 进入非图形界面快捷键是 ctrl + shift + f3， 需要你重新登陆以下你的用户
# 然后让terminal进入当前有这个script的文件夹
# 如果是laptop双显卡（intel和nvidia）， 则在terminal输入 bash ./deepin_nvidia_install_2.sh laptop
# 如果是电脑（单显卡nvidia,且nvidia 显卡为10，20或30系），则直接 bash ./deepin_nvidia_install_2.sh



# -------------------------------------------------------------------------------------------------------------
# SIGINT is when you press ctrl+C, trap it and exit
# trap single quote, only analyse the command when triggered
trap 'catch INT signal\n"; exit' SIGINT SIGTERM
# kill 0 will send SIGINT signal to all group process, but kill 0 is dangerous!
trap 'echo "catch EXIT signal\n"; kill $beatpid ' EXIT

# -----------------------------------  sudo beat ---------------------------------------
# get sudo and || means only if sudo -v fails, it will run the second command, $? means get the signal from the previous command
sudo -v || exit $?

# just wait for a while so that the credential is saved in cache
sleep 1

# while loop
{
    # save child pid
    echo "child process is $BASHPID"
    echo "$BASHPID" >"/tmp/tempsudobeat-$(date +%Y-%m-%d)-$$.txt"

    while true; do
        echo "sudo beat! BOOM!"
        # -n means if require password then directly exit, -v means extend sudo timeout
        sudo -n -v
        sleep 30
    done

} &

# let sudo beat child process to warm up
sleep 3

read beatpid <"/tmp/tempsudobeat-$(date +%Y-%m-%d)-$$.txt"
# --------------------------------------------- sudobeat ---------------------------------------------
# 以上是为了保持在安装过程中一直有sudo权限，以下才是 nvidia 显卡驱动安装代码的主体

# 检测 是否是laptop 模式
if [ $1 == "laptop" ]; then
    echo "runing laptop mode"
else
    echo "running normal mode"
fi

# 定义黑名单的文件地址
blacklistfile=/etc/modprobe.d/blacklist.conf
# blacklistfile=test.txt
# 定义apt source文件地址
sourcelist=/etc/apt/sources.list
# sourcelist=source.list

# 把不兼容的开源nvidia驱动设置黑名单
echo blacklist nouveau | sudo tee $blacklistfile
echo options nouveau modeset=0 | sudo tee -a $blacklistfile

# 把debian nvidia驱动的非稳定源写入apt源
echo deb http://deb.debian.org/debian buster-backports main contrib non-free | sudo tee -a $sourcelist

# 更新黑名单
sudo update-initramfs -u
# 关闭lightdm 先
sudo service lightdm stop
sudo apt update
# 删除原本的各种驱动
sudo apt remove nvidia* -y
# 安装nvidia-detect
sudo apt install nvidia-detect -y
sudo apt install curl -y

if [ $1 == "laptop" ]; then
    sudo apt install nvidia-driver firmware-misc-nonfree nvidia-cuda-dev nvidia-cuda-toolkit nvidia-smi nvidia-settings nvidia-cuda-mps vulkan-utils -y
    # --------------------- only for Optimus two GPU laptop -------------------------
    # https://github.com/zty199/dde-dock-switch_graphics_card
    # 提前下载好这个
    if [ ! -f ./dde-dock-graphics-plugin_1.8.1_amd64.deb ]; then
        echo download dde dock graphics plugin
        curl -L https://github.com/zty199/dde-dock-switch_graphics_card/releases/download/1.8.1/dde-dock-graphics-plugin_1.8.1_amd64.deb --output ./dde-dock-graphics-plugin_1.8.1_amd64.deb
    fi

    if [ ! -f ./prime-run.desktop ]; then
        echo write prime-run desktop file
        cat >./prime-run.desktop <<EOL
[Desktop Entry]
Type=Application
Exec=/usr/bin/prime-run %u
GenericName=Run with prime-run
Name=Run with prime-run
MimeType=application/x-shellscript;application/x-sharedlib;application/x-executable;application/x-desktop;
GenericName[en]=Run with prime-run
GenericName[zh_CN]=使用 prime-run 运行
Name[en]=Run with prime-run
Name[zh_CN]=使用 prime-run 运行
X-DFM-MenuTypes=SingleFile
X-DFM-SupportSchemes=file
X-Deepin-Vendor=user-custom
EOL
    fi
    chmod +x ./dde-dock-graphics-plugin_1.8.1_amd64.deb
    chmod +x ./prime-run.desktop

    sudo dpkg -i ./dde-dock-graphics-plugin_1.8.1_amd64.deb

    sudo apt --fix-broken install
    # 装两遍因为第一遍可能因为缺少dependency装不上
    sudo dpkg -i ./dde-dock-graphics-plugin_1.8.1_amd64.deb

    sudo rsync -auvPh ./prime-run.desktop /usr/share/deepin/dde-file-manager/oem-menuextensions/
    # -------------------- only for Optimus two GPU laptop END -----------------------

else
    sudo apt install -t buster-backports nvidia-driver firmware-misc-nonfree nvidia-cuda-dev nvidia-cuda-toolkit nvidia-smi nvidia-settings nvidia-cuda-mps vulkan-utils -y
fi

sudo apt install mesa-utils -y
sleep 5
reboot

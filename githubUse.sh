#!/bin/sh

workdir=/workdir
openwrtCodeDir=$workdir/openwrt_code
buildUser=who

dockerRun(){
  docker run --rm -t --workdir "$workdir" -v "$(pwd):$workdir" -v "$GITHUB_ENV:$GITHUB_ENV" --env GITHUB_ENV=$GITHUB_ENV openwrt -c "./$(basename $0) $*"
}

# 设置GitHub工作流环境变量
setEnv() {
  echo "$1=$2" >> $GITHUB_ENV
}

cloneOpenWrtCode(){
  cd "$workdir"
  if [ -d "$openwrtCodeDir"/.git ];then
    echo 更新OpenWrt源码
    cd "$openwrtCodeDir"
    git checkout .
    git pull --strategy recursive --strategy-option=theirs
  else
    echo 克隆OpenWrt源码
    git clone https://github.com/openwrt/openwrt.git -b master "$openwrtCodeDir"
  fi
}

updatingFeeds(){
  cd "$openwrtCodeDir"
  ./scripts/feeds update -a
}

installFeeds(){
  cd "$openwrtCodeDir"
  ./scripts/feeds install -a
}

expandConfig(){
  cp -f diffconfig.ini "$openwrtCodeDir"/.config
  cd "$openwrtCodeDir"
  make defconfig
}

downloadDependency(){
  cd "$openwrtCodeDir"
  make download -j9 || make download -j1 V=s
  if [ $? = 0 ]; then
    echo "::set-output name=status::success"
  else
    echo "::set-output name=status::fail"
  fi
}

chownBuildUser(){
  chown -R $buildUser "$openwrtCodeDir"
}

getCommitDateTime(){
  cd "$openwrtCodeDir"
  log=$(git log --pretty=format:"%cd|||%cn|||%s" -1 --date=unix)
  timestamp=$(echo $log | grep -o '^[0-9]\+')
  dateTime=$(date --date="@$timestamp" +"%Y-%m-%d_%H%M%S")
  setEnv GIT_COMMIT_DATE_TIME $dateTime
  echo "OpenWrt源码的提交时间是$dateTime"
}

getBuildStartDateTime(){
  export TZ='Asia/Shanghai'
  dateTime=$(date +"%Y-%m-%d_%H%M%S")
  setEnv BUILD_START_DATE_TIME $dateTime
  echo 时间是$dateTime
}

patchFile() {
  #sed -i -e 's#\(tools-y.\+\) fakeroot#\1#' tools/Makefile
  file=build_dir/host/fakeroot-*/libfakeroot.c
  if [ -e $file ]; then
    echo 有libfakeroot.c
    head -1 $file | grep -q _STAT_VER || sed -i -e '1i#define _STAT_VER 0' $file
    sed -i -e 's#^\(typedef int id_t\)#//\1#' $file
  else
    echo 没有libfakeroot.c
  fi

  file=staging_dir/host/lib/libfakeroot.so
  if [ -e $file ]; then
    echo 有$file
    cp /usr/lib/libfakeroot.so $file
  else
    echo 没有$file
  fi

  file=staging_dir/host/bin/fakeroot
  if [ -e $file ]; then
    echo 有$file
    ln -sf $(which fakeroot) staging_dir/host/bin/fakeroot
  else
    echo 没有$file
  fi
  
}

compileFirmware(){
  cd "$openwrtCodeDir"
  cpu=$(nproc)
  echo CPU核心数为$cpu
  jobs=$((cpu + 1))
  patchFile

  case "$1" in
  1)
    echo 单核调试编译
    make -j1 V=s
    ;;
  e)
    echo 多核忽略错误编译
    export IGNORE_ERRORS=1
    make -j$jobs
    patchFile
    make -j$jobs || make -j1 V=s
    ;;
  *)
    echo 多核正常编译
    make -j$jobs
    ;;
  esac
  if [ $? = 0 ]; then
    echo 编译固件成功
    setEnv COMPILE_FIRMWARE_STATUS success
    grep '^CONFIG_TARGET.*DEVICE.*=y' .config | sed -r 's/.*DEVICE_(.*)=y/\1/' > DEVICE_NAME
    [ -s DEVICE_NAME ] && setEnv DEVICE_NAME $(cat DEVICE_NAME) && rm DEVICE_NAME
  else
    echo 编译固件失败
    if [ "$1" = e ]; then
      exit 2
    fi
  fi
}

cleaningUp(){
  cd "$openwrtCodeDir"
  make clean
}

# 以普通用户执行
ordinaryUserRun() {
  if [ "$(whoami)" = "root" ]; then
    su $buildUser -pc "$0 $*"
  else
    echo 我是$(whoami)，将执行$@
    $@
  fi
}

case "$1" in
  dockerRun)
    shift
    dockerRun "$@"
    ;;
  disposeOpenWrtCode)
    ordinaryUserRun cloneOpenWrtCode
    ordinaryUserRun getCommitDateTime
    chownBuildUser
    ;;
  *)
    ordinaryUserRun $@
    ;;
esac

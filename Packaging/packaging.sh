#!/bin/sh

# 当前shell所处的目录
shell_dir_path=$(cd "$(dirname "$0")"; pwd)

# 把配置文件里的参数在该脚本里全局化
source $shell_dir_path"/global.config"

echo "开始检查环境..........."

# 如果归档文件夹不存在则创建
if [ ! -d $package_root_path ]; then
    mkdir -pv $package_root_path
fi

# 如果不存在记录文件则创建，存在文件则把文件内容变量加入到全局变量
if [ -e $package_root_path"result.txt" ]; then
    source $package_root_path"result.txt"
    # 判断svn最后提交信息是否已经归档过，其中SVN_REVISION是SVN提交时的编号，改变量
    # 是Jenkins提供的
    if [ $lastestBuildVersion = $SVN_REVISION ] ; then
        echo "该版本已经打过包了，请重新提交一次记录并确保is_need_package为true"
        exit 1
    else
        # 为了节省空间，所以每次打包都会在开始前移除之前文件
        rm -rf $package_archive_path*
        echo "移除旧项目完毕，准备工作已就绪"
    fi
else
    # 创建记录文档
    touch $package_root_path"/result.txt"
    chmod -R 777 $package_root_path"/result.txt"
    echo lastestBuildVersion=0 >> $package_root_path"/result.txt"

fi

# 检查是否需要打包
if ! $is_need_package; then
    exit 1
fi

# 检查是否设置target/scheme
if test -z $package_target_name; then
	echo "❌ 项目Target设置为空"
	exit 1
fi

if test -z $package_scheme_name; then
	echo "❌ 项目Scheme设置为空"
	exit 1
fi

# 读取配置文件归档类型是Release还是Debug
if $package_use_release; then
    build_configuration="Release"
else
    build_configuration="Debug"
fi


#  AdHoc: 1, AppStore: 2, Enterprise: 3, Development: 4
# 导出ipa包的plist文件夹，该文件在打包时会生成
options_dir_path=$package_export_options_dir_path
if [[ $package_export_type -eq 1 ]]; then
    export_options_plist_path=$options_dir_path"AdHocExportOptions.plist"
    export_type_name="AdHoc"
elif [[ $package_export_type -eq 2 ]]; then
    export_options_plist_path=$options_dir_path"AppStoreExportOptions.plist"
    export_type_name="AppStore"
elif [[ $package_export_type -eq 3 ]]; then
    export_options_plist_path=$options_dir_path"EnterpriseExportOptions.plist"
    export_type_name="Enterprise"
elif [[ $package_export_type -eq 4 ]]; then
    export_options_plist_path=$options_dir_path"DevelopmentExportOptions.plist"
    export_type_name="Development"
fi

echo "✅✅✅ 校验参数以及环境成功"
echo "⚡️ ⚡️ ⚡️即将开始打包 ⚡️ ⚡️ ⚡️"

##############################自动打包部分##############################

# 返回到工程目录
cd ../
project_path=`pwd`

# 获取项目名称
project_name=`find . -name *.xcodeproj | awk -F "[/.]" '{print $(NF-1)}'`
# 指定工程的Info.plist
current_info_plist_name="Info.plist"
# 配置Info.plist的路径
current_info_plist_path="${project_name}/${current_info_plist_name}"
# 获取项目的版本号
bundle_version=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ${current_info_plist_path}`
# 获取项目的编译版本号
bundle_build_version=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ${current_info_plist_path}`

# 当前版本存放导出文件路径，可以根据需求添加不同的路径
currentVersionArchivePath="${package_archive_path}"

# 判断归档当前版本文件夹是否存在，不存在则创建
if [ ! -d $currentVersionArchivePath ]; then
    mkdir -pv $currentVersionArchivePath
    chmod -R 777 $currentVersionArchivePath
fi

# 归档文件路径
export_archive_path="${currentVersionArchivePath}${package_scheme_name}.xcarchive"
# ipa导出路径
export_ipa_path="${currentVersionArchivePath}"
# 获取时间 如:20190630_1420
# current_date="$(date +%Y%m%d_%H%M)"
# ipa 名字, 可以根据版本号来进行重命名
ipa_name="${package_scheme_name}_${SVN_REVISION}.ipa"

echo "工程目录 = ${project_path}"
echo "工程Info.plist路径 = ${current_info_plist_path}"
echo "打包类型 = ${build_configuration}"
echo "打包使用的plist文件路径 = ${export_options_plist_path}"

###############################打包部分#########################################

echo "🔆🔆🔆正在为您开始打包🚀🚀🚀🚀🚀🚀"

# 是否使用xxx.xcworkspace工程文件进行打包
if $package_use_workspace; then

    if [[ ${build_configuration} == "Debug" ]]; then
        # 1. Clean
        xcodebuild clean  -workspace ${project_name}.xcworkspace \
        -scheme ${package_scheme_name} \
        -configuration ${build_configuration}

        # 2. Archive
        xcodebuild archive  -workspace ${project_name}.xcworkspace \
        -scheme ${package_scheme_name} \
        -configuration ${build_configuration} \
        -archivePath ${export_archive_path} \
        CFBundleVersion=${bundle_build_version} \
        -destination generic/platform=ios \

    elif [[ ${build_configuration} == "Release" ]]; then

        # 1. Clean
        xcodebuild clean  -workspace ${project_name}.xcworkspace \
        -scheme ${package_scheme_name} \
        -configuration ${build_configuration}

        # 2. Archive
        xcodebuild archive  -workspace ${project_name}.xcworkspace \
        -scheme ${package_scheme_name} \
        -configuration ${build_configuration} \
        -archivePath ${export_archive_path} \
        CFBundleVersion=${bundle_build_version} \
        -destination generic/platform=ios \

    fi

else

    if [[ ${build_configuration} == "Debug" ]] ; then
        # 1. Clean
        xcodebuild clean  -project ${project_name}.xcodeproj \
        -scheme ${package_scheme_name} \
        -configuration ${build_configuration} \
        -alltargets

        # 2. Archive
        xcodebuild archive  -project ${project_name}.xcodeproj \
        -scheme ${package_scheme_name} \
        -configuration ${build_configuration} \
        -archivePath ${export_archive_path} \
        CFBundleVersion=${bundle_build_version} \
        -destination generic/platform=ios \

    elif [[ ${build_configuration} == "Release" ]]; then
        # 1. Clean
        xcodebuild clean  -project ${project_name}.xcodeproj \
        -scheme ${package_scheme_name} \
        -configuration ${build_configuration} \
        -alltargets

        # 2. Archive
        xcodebuild archive  -project ${project_name}.xcodeproj \
        -scheme ${package_scheme_name} \
        -configuration ${build_configuration} \
        -archivePath ${export_archive_path} \
        CFBundleVersion=${bundle_build_version} \
        -destination generic/platform=ios \

    fi
fi

# 检查是否构建成功
# 因为xxx.xcarchive 是一个文件夹不是一个文件
if [ -d ${export_archive_path} ]; then
    echo "🚀 🚀 🚀 项目构建成功 🚀 🚀 🚀"
else
    echo "⚠️ ⚠️ ⚠️ 项目构建失败 ⚠️ ⚠️ ⚠️"
    exit 1
fi

echo "开始导出ipa文件"
# 导出ipa文件
xcodebuild -exportArchive -archivePath ${export_archive_path} \
-exportPath ${export_ipa_path} \
-destination generic/platform=ios \
-exportOptionsPlist ${export_options_plist_path} \
-allowProvisioningUpdates
# 默认导出ipa文件路径
export_ipa_name=$export_ipa_path$package_scheme_name".ipa"

# 判断是否有这个导出ipa文件
if [ -e $export_ipa_name ]; then
    # 更改名称为 scheme_version.ipa scheme名称为工程名称，version为svn最后提交的版本
    mv $export_ipa_name $export_ipa_path$ipa_name
    # 将当前版本设为已打包状态
    echo lastestBuildVersion=$SVN_REVISION > $package_root_path"result.txt"
    echo "🎉 🎉 🎉 导出 ${ipa_name}.ipa 包成功 🎉 🎉 🎉"
else
    echo "❌ ❌ ❌ 导出 ${ipa_name}.ipa 包失败 ❌ ❌ ❌"
fi

# 输出打包总用时
echo "本次打包总耗时: ${SECONDS}s"


############################上传部分#####################################

function createUploadShell(){
    touch upload.sh
    chmod -R 777 upload.sh
    echo "cd ${package_archive_path}" >> upload.sh
    echo "ftp -i -n -v << !" >> upload.sh
    echo "open xxx.xx.xxx.xx" >> upload.sh
    echo "user oymuzi xxxx" >> upload.sh
    echo "cd ./${upload_dir_path}" >> upload.sh
    current_date="$(date +%Y%m%d%H%M%S)"
    ipa_new_name=$package_scheme_name"_"$current_date".ipa"
    echo "binary" >> upload.sh
    echo "put ${upload_volumes_name}${package_archive_path}${ipa_name} ./${ipa_new_name}" >> upload.sh
    echo "close" >> upload.sh
    echo "bye" >> upload.sh
    echo "!" >> upload.sh
}

cd $package_archive_path
createUploadShell
echo "创建上传脚本成功"

echo "🚀 🚀 🚀 开始上传至云端  🚀 🚀 🚀"
sh upload.sh
echo "上传至云端完成"

rm -f upload.sh


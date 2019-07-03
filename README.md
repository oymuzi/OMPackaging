### 前言

之前写过一篇[基于Jenkins和Fastlane自动打包]()的文章，文中简述了很多的的环境搭建以及一些遇到的问题。这篇文章的目的是使用脚本和**Jenkins**来自动打包，为何不在使用之前的**Fastlane**呢？首先**Fastlane**是很不错的，也是使用**xcodebuild**命令来封装实现的，但是在使用过程中会涉及到一个脚本的迁移能力即运用到其他项目上，我认为是不算高的，至少在**Jenkins**上。反正**Fastlane**也是基于**xcodebuild**来进行编译打包的，那我们何不直接编写脚本进行打包呢？

还有一个问题就是大家都知道使用**Git**基于**Jenkins**的自动化打包可以直接在每次提交时实现自动打包，但是在**Jenkins**中使用**SVN**我们没有发现类似这个功能的插件。文中的解决办法是一种曲线救国的方法，在文章的下半部分会讲到。我一开始的构思还是想通过局域网来实现，但是越到后面发现行不通，没有感觉到自动打包带来的便利。**于是有了本文这个方案**。



### 准备

①请确保打包电脑的环境已经安装好了HomeBrew、Jenkins(建议使用brew安装Jenkins并进行开机自启动)

②请确保打包电脑的要是串中有你需要打包的APP所需的证书、描述文件

③请确保此打包脚本用于基于提交SVN和Jenkins环境中自动打包，否则将会导致脚本不可用的状态😂😂



### 打包结构

具体的结构可以参照下图，如果有其他的类型的打包，可以在Plist文件夹中添加新的plist文件，这个文件可以在手动打包时导出的文件夹里有xxxExportOptions.plist文件。然后在配置文件里面进行更改类型。

![](http://cloud.minder.mypup.cn/blog/%E8%87%AA%E5%8A%A8%E6%89%93%E5%8C%85%E7%BB%93%E6%9E%84%E5%9B%BE.jpg)



#### 前戏

修改配置文件就能直接控制打包类型是不是很方便。一开始采用json文件来进行配置，使用json文件的话对我来说有两个缺点。其一就是json文件中无法进行注释，这会导致后面接手的人无法明白其意，或者需要在添加一个说明文档；其二是因为在使用json配置路径的时候还需要对值进行去除双引号，可以实现很麻烦。另外就是Shell解析json数据还是有点麻烦，使用jq解析挺方便就是得配置一下环境。其中global.config代码如下：

```

	#是否需要打包
	is_need_package=true

	#生产环境/开发环境证书设置
	code_sign_distribution="iPhone Distribution: xxxx xxx (xxx)"
	code_sign_development="iPhone Developer: xxxx xxxx (xxx)"

	#项目的target/scheme设置 
	package_target_name="xxx"
	package_scheme_name="xxx"

	#打包结果根目录
	package_root_path=/Users/xxx/Desktop/Package/
	#打包ipa目录
	package_archive_path=/Users/xxx/Desktop/Package/Archive/

	#打包类型  AdHoc：1 AppStore：2  Enterprise：3  Development：4
	package_export_type=1
	#打包存放的xxxExportOptions.plist文件夹
	package_export_options_dir_path=./AutoPacking/Plist/

	#是否使用workspace进行打包
	package_use_workspace=true
	#是否使用Release模式进行打包
	package_use_release=true

	#记录打包前缀
	record_perfix="CEG"
```



是不是觉得很简单，但是阅读性不是很高吧， 在Xcode中没有高亮显示，都是一个色容易犯困。但是使用超级简单

```
source global.config
```

是不是很简单，😀😀，只需要一个命令，即可获得全部的全局变量，$is_need_package就能获得值，路径也是，所以我选择了这种方式来进行做配置文件，对不同的人有不同的效果，对我不熟悉脚本的人真的太有好了。有个注意点就是一行只能写一个变量，并且变量和值之间只能有等于号，不能有空格号来进行对齐🤡🤡，是不是觉得连最后的美化机会都没有啦😏。其实习惯就好。🙂



#### 后戏

小伙子别盯着看标题哈，思想很危险哈😅，我不是来开车的，说完配置文件就该说说这个打包脚本了。还记得准备工作中说了要在**SVN**中吗，因为用到了Jenkins中全局构建参数**SVN_REVISION**,另外看这个脚本其实有点烦，因为很大部分代码是在做前戏工作😉😉，真正**xcodebuild**命令在末尾了。另外我写脚本喜欢都是小写，全大写的看着头痛啊， 所以我也不知道这符不符合脚本的代码规范吧，但是自我感觉良好😎😎。

```
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
```

是不是有点头晕哇，我是头痛啊🤗🤗，玩过使用**Jenkins**脚本自动打包的人看完这个应该知道我的曲线救国方式了，有的同学肯定还在😳😳or🤔🤔。我们在**重头戏**中讲🤗🤗。



### 重头戏

看风格我就不是开车的人，因为开车哪来这么多前戏是吧？🤔🤔，开始剥丝抽茧啦。

前面说到在**Jenkins**中没有类似**Git**这样的提交代码自动打包的钩子插件。而我们使用**Jenkins**的目的就是为了释放程序员的👐，留着更多时间干正事，如果不能实现提交自动打包那有无**Jenkins**都一样了，还不如自己写个脚本打包呢，是吧？如果是你你会怎么做呢？

我们知道Jenkins有个定期执行任务的选项，我们只需填上参数：H/2 * * * *  然后就会每两分钟执行一次，是不是想说为啥不设置1分钟，我也想哇，**Jenkins**不让啊😞😞。但是总不能让这家伙每两分钟一直打吧，覆盖还好，但是每两分钟就有一个新的安装包上传至测试服务器也不好吧，感觉会被测试人员打屎😱😱。那么我们就需要解决这个打断打包的条件🤔。既不能在工程中设置，不然**Jenkins**每次执行任务就覆盖了，也就是只能在打包电脑上保存一个状态。那么很好解决啦，我们只需要在脚本中创建一个文件来记录上次打包的**SVN_REVISION**，就能让脚本读取文件记录判断是否已经打过包了，没有打过包才执行程序，否则退出程序。😉😉现在想想是不是很简单哇，然后就可以尽情的哒哒哒。



使用FTP上传至测试服务器这部分该如何解决呢？因为涉及到可变参数，脚本那么差的我只能使用土办法，一招一招来，干到不服为止😁😁。这部分脚本是上面那长串代码的末尾后的代码。

```
############################上传部分#####################################

function createUploadShell(){
    touch upload.sh
    chmod -R 777 upload.sh
    echo "cd ${package_archive_path}" >> upload.sh
    echo "ftp -i -n -v << !" >> upload.sh
    echo "open 117.xx.xxx.xxx" >> upload.sh
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
```

对，就是这么feel 倍爽，大佬可以自己进行更改脚本。其中一点就是使用FTP命令必须使用`ftp -i -n -v << !  你想要的执行的FTP命令  !`。至于上传公司服务器还是蒲公英等平台，这个可以根据各自公司的规则吧，自己进行修改哈。



源码地址：[OMPackaging]()(注：此demo仅为了展示源码，按照源码和文章所说的办法设置环境即可正常打包)



### 言归正传

利用**Jenkins**的定死执行任务功能，在本地保存一个打包的状态，然后就能每次提交代码后进行自动打包，有1-2分钟的延迟，而且要执行打包必须确保配置文件中的`is_need_package`为true并提交一次代码。在上传至测试服务器，测试人员就能直接下载安装。这个方案虽然有些延迟，但是解决了自动打包的问题。





参考：

[Mac shell 上传文件(在shell中使用FTP命令)](https://blog.csdn.net/weixinyi21cn/article/details/79151620)

[Building from the Command Line with Xcode FAQ](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)


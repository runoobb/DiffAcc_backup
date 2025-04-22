# DiffAccelerator
# 代码开发规则
1. 所有变量、模块名等均采用驼峰命名法，对于模块名、常量名(Parameter), 所有单词首字母大写，如data input写作DataInput; 对于例化名、互连线、寄存器的命名，则第一个单词首字母小写，其余单词首字母大写，data input写作dataInput
2. 为使得文件之间的逻辑清晰，请尽量减少文件的数量，简单的模块且经常被复用的小模块融合到一个MCommon.sv和VCommon.sv文件中，Common.sv中包含一些可以复用的逻辑，大家都可以调用。
3. 模块之间的互联接口和重要架构参数在Common.sv中进行定义，需要更新请修改Common.sv
3. 整体代码风格可以参考Refer文件夹下的样例。
3. 为避免模块名字重复，VArray下所有模块名以V开头，MArray下所有模块名以M开头，Top下所有模块名以T开头。
4. 每个人加入仓库后，新建自己的分支（首先git branch \<branch-name\>创建分支，再git checkout \<branch-name\>切换到该分支）
5. 每次开发前先从仓库拉取最新的代码（pull）,再进行开发，以防止代码出现冲突，每更新一个重要的特性建议上传一次代码(commit+push)。# DiffAcc_backup

# 精简日历与农历标注

本次修改以 DexterW97/Itsycal-4-WB 为基础，参考 LunarBar 的双行日期展示方式。

## 界面

- 移除日历下方的日程列表、添加事件按钮、打开 Calendar 按钮和拖动条。
- 收紧日期网格和窗口底部留白，高亮底边至窗口底部约 5pt，保留月份轮廓描边。
- 顶部顺序：月份标题、上个月、今天、下个月、固定、设置菜单。
- 保持原有日历列宽和总宽度；日期格只增加高度，公历下方显示农历。
- 保留事件圆点、悬停事件详情、星期起始日、周数、三种字号、深浅色主题。
- 清除日程列表对应的设置和运行时逻辑；保留日历来源选择，用于事件圆点和详情。
- 保留双击日期和 ⌘N 新建日历事件、⌘O 打开系统日历、P 固定、⌘, 设置等快捷操作。

原项目没有独立的 Apple Reminders 集成；本次移除的是下方日程列表。事件仍由系统日历提供。

## 农历

- 使用 Foundation 的 Chinese Calendar，无新增第三方依赖或在线请求。
- 普通日期显示“初二、十八、廿一”等；初一显示月份，如“九月”；支持“闰六月”。
- 常见传统节日优先显示名称：春节、元宵、端午、七夕、中元、中秋、重阳、腊八、除夕。
- 除夕由下一日是否为正月初一判定，兼容腊月二十九和三十。
- 将每个公历日期解释为上海时区的正午，避免用户所在时区改变同一日期的农历标注。
- 这次未增加二十四节气、法定假期旗标或调休数据。

农历显示为独立实现，没有复制 LunarBar 的源码或资源。

## 更新来源

停止启动上游 Sparkle 更新周期；“检查更新”打开本 fork 的 GitHub Releases，避免本分支被上游安装包替换。

## 构建与测试

需要完整 Xcode。项目原有最低系统版本为 macOS 27.0。

```sh
cp Local.xcconfig.example Local.xcconfig
xcodebuild -project Itsycal.xcodeproj -scheme Itsycal -configuration Release \
  -derivedDataPath /tmp/itsycal-build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build

Tests/run-tests.sh
Tests/run-tests.sh --ui
```

UI 测试需要可用的 macOS 图形会话。截图输出在 `$TMPDIR/itsycal-calendar-tests/snapshots/`。

验证覆盖：已知农历日期、传统节日、29 天腊月除夕、闰月、无效日期、时区一致性；三种字号与周数显隐的六种组合；宽度保持、标签与事件圆点间距、闰月文字宽度、增删日期行、月份切换与回到今天；深浅色组件渲染。

未对用户的实际日历数据执行创建或删除操作。生成的应用仅使用本地临时签名，未进行 Apple 公证。

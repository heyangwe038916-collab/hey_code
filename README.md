# 行业信息日报网页版预览

本项目用于按配置采集保险行业相关信息，生成可人工核对的 HTML 网页邮件预览和 JSON 结构化结果，并支持通过 SMTP 发送邮件。

## 当前输出

默认运行后生成两个文件：

- `dist/industry_mail_preview.html`：网页版邮件预览，可直接用浏览器打开核对。
- `dist/industry_items.json`：结构化采集结果，包含栏目、条目、财务报告、偿付能力报告和失败原因。

HTML 预览包含：

- 顶部摘要：命中信息数、金监总局栏目数、同业栏目数、空栏目数。
- 国家金融监督管理总局：政策文件与法规、人事变动、行政许可。
- 行业及银行系同业：公开信息披露、财务信息、股权变动与偿付能力、负面舆情。

每个普通栏目默认最多展示 `3` 条，按日期倒序排列；当天日期会在 HTML 中高亮。

## 运行方式

安装依赖：

```powershell
python -m pip install -r requirements.txt
```

生成默认预览：

```powershell
python -m src.main
```

生成并发送邮件：

```powershell
python -m src.send_mail
```

快速重发已有 HTML，不重新采集：

```powershell
python -m src.send_mail --skip-generate
```

指定输出路径：

```powershell
python -m src.main --html dist\my_preview.html --json dist\my_items.json
```

只跑指定分组，便于调试：

```powershell
python -m src.main --only-group nfra
python -m src.main --only-group industry
python -m src.main --only-group solvency
```

跳过真实网络采集，仅验证输出链路：

```powershell
python -m src.main --no-network
```

运行测试：

```powershell
python -m pytest
```

## 系统逻辑

主入口是 `src/main.py`：

1. 读取 `config/sources.yaml`。
2. 创建 `NfraCrawler` 执行采集。
3. 运行 `validate_preview_result` 做基础结果校验。
4. 写入 JSON。
5. 调用 `render_preview` 生成 HTML。

采集失败不会直接中断整体任务。失败信息会写入 `result.failures`，并在命令行输出前若干条样例，方便排查外部网站 404、SSL、限流、超时等问题。

## 采集范围

### 金监总局

配置位置：`config/sources.yaml` 的 `sources.nfra`。

当前包含三个栏目：

- `policy_documents`：政策文件与法规，关注公司治理、股权管理、偿付能力等主题。
- `personnel`：人事变动，当前口径限定为监管系统干部调整类信息。
- `administrative_approvals`：行政许可，当前口径限定为寿险/人身险公司股东、股权、注册资本金变更相关批复。

金监总局请求使用较长间隔，默认 `nfra_request_interval_seconds: 15`，用于降低触发限流的概率。

### 人事变动口径

人事栏目不是普通保险机构高管任职资格批复栏目。

当前保留逻辑：

- 允许金监总局、地方金融监管局、配置内微信公众号来源。
- 需要体现监管系统干部调整信号，如司局级、司长、副司长、局长、副局长、处长、党委书记、纪委书记、人事调整、履新、调任等。
- 已配置重点兜底文章：慧保天下《金融监管总局新一轮人事大调整：全年101人履新，专业化开放化凸显，80后崭露锋芒》。

当前排除逻辑：

- 排除“任职资格批复 + 公司/高管角色”的普通机构任职信息。
- 典型排除项包括保险代理、保险经纪、货币经纪、保险公估、财险、保险公司董事、总经理、副总经理、总裁助理、总经理助理等。
- 公务员考试、录用、招聘、百科、文库等非目标内容也会过滤。

### 同业公司

配置位置：`config/sources.yaml` 的 `insurance_companies`。

当前覆盖 15 家保险公司或集团相关主体：

- 光大永明
- 中华人寿
- 中邮人寿
- 工银安盛
- 建信人寿
- 交银人寿
- 农银人寿
- 中信保诚
- 中国人寿
- 中国平安
- 中国人保
- 中国太保
- 泰康保险
- 新华人寿
- 中国太平

同业栏目来自 `industry_sections`：

- `governance`：公司治理，目前在 HTML 汇总中跳过展示。
- `disclosure`：公开信息披露，以公司入口链接形式展示。
- `equity_change`：股权变动与偿付能力，结合官网、搜索和微信公众号补充。
- `negative_public_opinion`：负面舆情，当前监测“中银三星人寿保险有限公司”，只采集约定微信公众号中当年最近 `10` 条风险新闻。
- `financials`：财务信息，主要汇总财务报告中的关键指标。

### 负面舆情口径

负面舆情栏目位于“股权变动与偿付能力”之后，当前只针对“中银三星人寿保险有限公司”。

当前保留逻辑：

- 只允许配置内微信公众号来源，包括新增的“消费日报财经”。
- 只展示当年信息，按日期倒序最多展示 `10` 条。
- 风险词分为高危、中危和一般三类，覆盖偿付能力下滑、监管处罚、重大违法违规、财务造假、高管被调查、大规模退保、重大投诉、重大诉讼、评级下调、资金链风险、业绩和净利润下滑、渠道违规销售、虚假宣传、数据泄露、产品投诉、代理人流失、分支机构处罚、网络舆情争议、服务质量投诉、营销争议、产品争议、高管离职、退保、资产下跌等。

当前排除逻辑：

- 不展示非配置公众号来源、普通门户转载和搜索页。
- 不展示往年信息。
- 排除招聘、考试、股吧、基金吧等非目标内容。

### 财务和偿付能力

财务信息主要围绕各公司配置的 `finance_report_title`、别名、指标覆写和单位规则生成。

展示字段包括：

- 公司
- 净利润
- 净资产
- 核心 / 综合偿付能力充足率
- 总资产
- 日期
- 来源

部分公司配置了 `finance_metric_overrides` 或 `force_finance_metric_overrides`，用于处理官网或 PDF 自动解析不稳定、单位不一致、扫描件无法提取等情况。

独立偿付能力表采集配置在 `solvency_companies`，当前包含：

- 光大永明人寿保险有限公司
- 中华联合人寿保险股份有限公司

偿付能力交叉验证使用 `validation_sites` 中配置的网站，失败不会阻断主 HTML 生成。

## 外部来源

允许的外部检索和验证站点包括：

- 国家金融监督管理总局
- 证券时报网
- 财联社
- 中国经济网
- 东方财富网
- 巨潮资讯网
- 每日财报网
- 和讯网
- 中国保险行业协会
- 中国货币网

微信公众号补充来源包括：

- 13个精算师
- 险联社
- 中保新知
- 慧保天下
- 圈中人保险网
- 险企高参
- 险企观察
- 圈中人寿险资源网
- 消费日报财经

普通微信检索默认关注近 `3` 天；人事类微信检索默认关注近 `180` 天。

## 配置维护

主要配置文件：`config/sources.yaml`。

常用维护点：

- 调整每栏展示数量：`settings.max_items_per_section`。
- 调整请求超时：`settings.request_timeout_seconds`。
- 调整金监总局请求间隔：`settings.nfra_request_interval_seconds`。
- 增加重点人工兜底条目：在对应栏目添加 `manual_items` 或公司下的 `manual_section_items`。
- 增加或修改保险公司：维护 `insurance_companies` 下的公司名称、官网入口、栏目入口、财报标题、指标覆写。
- 调整外部验证站点：维护 `allowed_external_sites` 和 `validation_sites`。
- 调整微信公众号范围：维护 `wechat_accounts`、`wechat_recent_days`、`personnel_wechat_recent_days`。
- 调整负面舆情公司、风险词和展示数量：维护 `industry_sections.negative_public_opinion` 下的 `targets`、关键词和 `item_limit`。

## 缓存和本地文件

金监总局栏目在成功采集时会写入 `dist/section_cache`。当后续网络失败但存在缓存时，系统可回退使用缓存，避免预览完全为空。

中国太平偿付能力栏目配置了本地 HTML 兜底文件：

- `需求/中国太平-偿付能力.html`

OCR 和 PDF 解析缓存位于 `dist/ocr_cache` 等目录，用于减少重复解析成本。

## 注意事项

- SMTP 发信读取 `.env.local`，不要把邮箱授权码提交或发送给他人。
- 外部网站搜索结果可能不稳定，尤其是搜索页、微信公众号、PDF 扫描件和反爬页面。
- `failures` 中出现 404、SSL、502、限流或超时并不一定代表整体失败，需要结合 HTML 和 JSON 核对。
- 对业务口径敏感的栏目，优先通过配置兜底项和测试用例固定规则，避免搜索结果漂移导致误展示。

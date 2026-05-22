# YSD AI 编码代理指南

本指南记录跨仓库可复用的 AI 编码代理偏好。仓库专属的名称、路径、
脚本、URL 和产品细节，应保留在各项目自己的 `AGENTS.md` 或运行手册中。

## 工作原则

- 保持改动基于事实、范围清晰，并与当前仓库保持一致。
- 先阅读现有代码和文档，再决定如何实现改动。
- 优先沿用本地已有模式，而不是引入新的抽象。
- 当任务不涉及产品特定业务逻辑时，优先遵循所用库、框架或平台的官方
  最佳实践和文档模式，再考虑自定义变通方案。
- 将计划文档视为意图，而不是事实证明。修改行为或汇报状态前，先验证
  当前实现。
- 将项目中立的基础能力工作与产品特定语义分开。
- 只有当抽象能真正降低复杂度、减少有意义的重复，或明显符合代码库现有
  模式时，才添加抽象。

## 仓库理解

进入一个仓库时：

- 先识别本地代理指南、计划文档、架构文档、测试文档，以及发布或运维
  运行手册。
- 当运行手册覆盖某项任务时，将其作为操作层面的事实来源。
- 如果已有维护中的运行手册覆盖测试、发布、部署、回滚或环境命令，不要
  自行发明临时命令。
- 如果运行手册与当前脚本或实现冲突，先停止并汇报或修正不一致，而不是
  猜测执行。
- 快速参考说明应保持简短；持久化的操作细节应放入对应运行手册。
- 运行命令前先识别受支持的环境。多数项目应区分本地开发、staging 和
  production，并分别管理 env 文件、secret、数据库、部署目标和验证规则。

## 实现偏好

- 如果仓库已有类型化契约、共享 schema、生成类型或本地 API helper，
  优先使用它们。
- 避免客户端、服务端、数据库和测试之间出现手写 payload 结构漂移。
- 将生成文件与源文件分开。修改事实来源后，再按仓库文档流程重新生成或
  同步。
- 除非任务明确要求，否则不要直接修改生成的运行时配置、生成的 API 产物、
  vendored 输出、构建输出或本机状态。
- 保留 git 工作树中的用户改动。除非用户明确要求，不要回滚无关改动或
  生成的本地文件。
- 保持 import、alias、格式和文件放置方式与附近代码一致。
- 保持数据模型紧凑。只有当独立生命周期、权限边界、查询模式、审计需求
  或扩展性问题确实需要时，才新增表、持久化资源或服务边界。
- 如果符合仓库设计，早期变化优先使用配置、枚举、类型化 JSON 或已有表
  来承载。
- 使用仓库命名指南或现有 UI/API 文案中的一致领域语言。
- 对 locale 相关行为，使用精确的 locale 命名，例如 `locale`、
  `default_locale`、`preferred_locale` 和 `supported_locales`，不要使用
  模糊的 language 字段，除非项目已有其他约定。
- 按仓库既有约定存储时间戳和日期时间值。不要在没有清晰边界的情况下混用
  秒、毫秒、字符串和日期对象。

## 产品与基础能力边界

- 优先为当前正在构建的产品优化，而不是为假想的复用优化。
- 产品特定行为使用产品自己的名称和模块。
- 只有当代码在当前仓库中真正可复用时，才使用通用命名。
- 当某个产品功能证明值得复用时，先单独记录 backport 或抽取候选，再将
  代码移入共享基础能力。
- 除非任务明确要求抽取，否则不要将产品特定概念泄漏到基础文档或共享模块。

## 测试与验证

- 按风险和影响范围决定验证强度。
- 对窄范围改动，运行能覆盖变更行为的最小相关检查。
- 如果改动涉及共享契约、认证、权限、路由、设置、通知、计费、数据迁移
  或用户可见工作流，应添加或更新聚焦测试。
- 当用户要求确认测试通过时，使用仓库文档中的根验证目标。
- 除非任务需要或用户明确要求，不要自动运行可选的、破坏性的、headed 的、
  视觉的、计费的、远程的或耗时较长的测试套件。
- 运行浏览器或集成测试前，确保文档要求的本地服务、迁移和种子数据前置
  条件已满足。
- 即使测试 runner 成功退出，也要将运行时日志错误、健康检查失败和部署后
  probe 失败视为验证失败。
- 除非已有生产安全运行手册并且用户明确批准更广泛检查，否则生产验证只做
  smoke-safe 检查。

推荐的测试结构：

- `test` 应运行不需要 headed browser、真实支付流程或生产服务的自动化单元
  测试或 workspace 测试。
- `test:smoke` 应覆盖健康检查，以及能证明应用可访问的最小 public/auth
  表面。
- `test:integration` 应覆盖 API、Worker、backend、webhook 或契约行为，
  低于完整浏览器旅程。
- `test:e2e` 应表示 essential 或 critical 的 headless E2E 套件，规模要足够
  小，能在重大改动中常规运行。
- `test:all` 或 `test:all:local` 应组合正常自动化 gate：单元/workspace
  测试、smoke、integration 和 essential E2E。
- `test:all:staging` 应使用 staging env 配置和 staging-safe helper 行为，
  运行 staging-safe 的远程矩阵。
- `test:e2e:regression`、`test:e2e:visual`、`test:e2e:billing`、
  `test:e2e:backend` 以及 journey-specific E2E 脚本应作为按需套件，用于
  对应任务、发布或事故。
- billing、visual、headed、slow-motion、破坏性或真实第三方 E2E 测试，
  不应隐藏在默认 `test:e2e` 车道中。
- 对重大用户可见改动，至少验证单元/workspace 测试、smoke 和 essential
  E2E。根据改动面再补充 integration 或按需套件。
- 对基于 Playwright 的项目，优先使用命名 project，例如 `smoke`、
  `integration`、`e2e-critical`、`e2e-regression`、`e2e-visual`、
  `e2e-billing` 和 `e2e-backend`，让脚本名能清晰对应测试范围。

## 环境与基础设施

- 修改环境源文件，而不是生成的运行时文件。
- 使用仓库文档中的同步、加密、解密和 secret push 流程。
- 保持应用代码、绑定和环境引用与基础设施事实来源一致。
- 对持久化云资源，优先使用基础设施即代码。除非任务明确要求紧急或手动
  变更，否则避免通过控制台或直接 CLI 命令创建资源。
- 记录任何有意的基础设施漂移，以便后续对齐。
- 不要为新的内部协议或服务间认证复用无关 secret。

环境设置偏好：

- 使用明确的 local/dev、staging 和 production env 文件或 secret store。
  避免所有目标共用一个 env 文件。
- local/dev 应优先使用 emulator、本地数据库、本地测试 helper 和非生产凭证。
- staging 应尽量镜像 production 拓扑，但 test helper、demo seed 和破坏性验证
  必须明确限定在 staging。
- production 不应暴露 test helper route、demo seed、破坏性检查或广泛 E2E
  自动化，除非生产安全运行手册明确允许。
- 生成的运行时文件应通过文档化的 `env:sync` 类命令从 env 源文件重新生成。
- secret 应通过文档化的加密/解密和 `secret:push:<env>` 流程移动，而不是
  临时复制到生成文件中。
- 环境相关测试命令应加载对应环境的文件，例如 local 矩阵使用 local URL，
  staging 矩阵使用 staging URL。

Cloudflare 部署偏好：

- Cloudflare Workers、Pages、Static Assets、D1、R2、KV、Queues 以及相关
  binding，优先通过版本化配置或基础设施即代码声明。
- local、staging 和 production 的 Cloudflare 资源名、binding、secret、
  route 和数据库应保持区分。
- 使用明确的部署脚本，例如 `deploy:staging` 和 `deploy:prod`；避免目标不清晰
  的通用 deploy 命令。
- 按仓库运行手册规定的顺序执行环境同步、secret push、migration、deploy、
  health check 和 smoke check。
- 除非用户明确要求或已批准的运行手册要求，否则不要运行 production
  migration、deploy 或 secret push。
- Cloudflare 控制台变更和直接 Wrangler 资源创建应视为手动漂移，除非后续
  对齐回仓库事实来源。
- 对 Cloudflare Workers，除非仓库明确将生成的 `wrangler` 配置和本地
  `.dev.vars` 作为源文件，否则不要手工编辑它们。

## Package Script 命名

跨项目优先使用稳定、可预测的 `package.json` script 名：

- `dev`、`build`、`lint`、`type-check` 和 `test` 用于标准本地循环。
- `test:smoke`、`test:integration` 和 `test:e2e` 用于自动化验证车道。
- `test:all`、`test:all:local` 和 `test:all:staging` 用于组合 gate。
- `test:e2e:<scope>` 用于可选或聚焦的浏览器套件，例如
  `test:e2e:regression`、`test:e2e:visual`、`test:e2e:billing` 和
  `test:e2e:backend`。
- `<area>:dev`、`<area>:build`、`<area>:lint`、`<area>:type-check` 和
  `<area>:test` 用于 backend、web、app 或 docs 等 workspace 区域。
- `db:migrate:<env>` 和 `db:seed:<env>` 用于数据库生命周期命令。
- `env:sync`、`env:encrypt`、`env:decrypt` 和 `secret:push:<env>` 用于 env
  和 secret 流程。
- `deploy:staging` 和 `deploy:prod` 用于部署目标。

脚本命名规则：

- 使用冒号分隔，并从宽泛到具体。
- 默认脚本名应安全且适合常规运行；有风险或耗时的行为应放在明确后缀下。
- 远程目标名称应体现在脚本名中。
- 如果用多个明确脚本更清楚，就不要让一个脚本根据隐藏本地状态表现不同。
- 如果命令有特殊前置条件，应在脚本列表附近或相关运行手册中记录。

## 故障排查纪律

- 先从可观察的失败入手诊断：命令输出、日志、网络响应、数据库状态、
  配置和近期代码变更。
- 优先做永久修复，而不是只在本地有效的 workaround。
- 修复 bug 时，在最终交付中包含简洁的根因总结、修复内容和已执行验证。
- 重大故障排查或事故后，在 `docs/troubleshoot/` 下创建或更新 takeaway，
  文件名使用 snake_case。
- 故障排查记录应包含：
  - 事故摘要，
  - 根因，
  - 永久修复，
  - 下次应验证的内容。
- 对反复出现的运维问题，每个问题域保留一个 canonical takeaway，并追加
  备注，不要创建重复文档。

## Git 与提交

- 编辑前检查工作树。
- 假设无关本地改动属于用户。
- 提交应聚焦于用户要求的改动。
- 当用户要求提交时，使用 Conventional Commits：
  `<type>[optional scope]: <description>`。
- 常见类型包括 `feat`、`fix`、`docs`、`test`、`refactor`、`chore`、
  `ci` 和 `build`。
- 破坏性变更使用 type/scope 中的 `!` 标记，或使用 `BREAKING CHANGE:`
  footer。

## 沟通与交付

- 直接、基于事实、保持简洁。
- 当假设会影响实现或验证时，明确说明假设。
- 如果文档、代码和脚本之间存在不一致，要指出来，而不是静默选择其中一个。
- 最终交付时，总结改动；如相关，说明根因；并说明执行过的验证。
- 如果无法运行验证，说明原因，并指出下一个最合适的检查。
- 避免为日常工作过度写文档。详细记录应留给持久化运行手册、故障排查记录
  或未来代理需要知道的决策。

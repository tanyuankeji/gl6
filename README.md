# TAS6424E-Q1 D 类音频放大器 RTL 设计

> 基于 TI TAS6424E-Q1 数据手册的 **4 通道数字输入 D 类汽车音频放大器 RTL 模型**（学习 / 研究用途）。

## 项目简介

本项目根据 TAS6424E-Q1 数据手册，逐步进行架构分析、模块设计与 RTL 实现，目标是构建一个完整、可综合、可验证的 4 通道数字输入 D 类汽车音频放大器 RTL 模型，覆盖 I2C 控制、寄存器配置、芯片 / 通道状态机、音频接口、PWM 输出、负载诊断与多重保护等功能。

## 主要特性

- I2C 从机控制接口（4 个地址选项，支持 100 / 400 kbps）
- `0x00`–`0x79` 寄存器地址空间（30+ 寄存器）
- 芯片主状态机：`STANDBY / Hi-Z / MUTE / PLAY / DIAG`
- 4 通道独立通道状态机：`PLAY / Hi-Z / MUTE / DC_DIAG`
- I2S / LJ / DSP / TDM 等多种音频接口模式
- 4 通道 BTL PWM 输出（2.1 MHz 开关频率）
- DC / AC 负载诊断
- 过流 / 过温 / 欠压 / 过压 / 时钟丢失多重保护
- 全局异步复位、同步释放（`rst_n` 低有效）

## 目录结构

```
gl006/
├── rtl/          # Verilog RTL 设计源码（13 个文件）
├── doc/          # 架构分析、设计规格、模块详细设计与数据手册提取文本
├── doc_src/      # 源数据手册 PDF
├── 提问词.md     # 项目需求与流程说明
├── README.md     # 本文件
└── .gitignore
```

## RTL 模块清单

| 文件 | 模块 | 说明 |
|------|------|------|
| `tas6424e_defines.v` | 全局参数定义 | `define` 宏集中管理状态编码、寄存器地址、默认值、位域、时间常量 |
| `i2c_slave.v` | I2C 从机接口 | 4 地址选项，100 / 400 kbps，SCL / SDA 同步 |
| `register_file.v` | 寄存器文件 | `0x00`–`0x79` 地址空间映射 |
| `state_machine.v` | 芯片主状态机 | STANDBY / Hi-Z / MUTE / PLAY / DIAG |
| `channel_fsm.v` | 通道状态机 | 每通道 PLAY / Hi-Z / MUTE / DC_DIAG |
| `audio_interface.v` | 音频接口 | I2S / LJ / DSP / TDM 等模式，跨时钟域同步 |
| `pwm_generator.v` | PWM 生成器 | BTL 输出，2.1 MHz |
| `diagnostic_ctrl.v` | 诊断控制器 | DC / AC 负载诊断 |
| `fault_monitor.v` | 故障监控器 | 过流 / 过温 / 欠压 / 过压 / 时钟丢失 |
| `pin_control.v` | 引脚控制 | 输出使能与故障引脚 |
| `clock_monitor.v` | 时钟监控器 | 时钟丢失检测 |
| `protection.v` | 保护电路 | 多重保护仲裁 |
| `tas6424e_top.v` | 顶层模块 | 集成所有子模块 |

## 文档索引

- `doc/architecture_design.md` — 架构设计（目标、原则、时钟域、模块层次）
- `doc/architecture_analysis.md` — 架构分析
- `doc/architecture_refinement.md` — 架构细化
- `doc/module_design_detail.md` — 模块详细设计
- `doc/design_spec.md` — 设计规格
- `doc/dc_diag_analysis.md` — DC / 诊断分析
- `doc/datasheet_text.md` / `datasheet_extracted.txt` — 数据手册文本提取
- `doc/extract_pdf.py` — PDF 文本提取脚本
- `doc_src/tas6424e-q1_260708_092629.pdf` — 源数据手册

## 使用与仿真

- 源码为纯 Verilog（IEEE 1364-2005），可综合、无 `initial` 延迟。
- 设计文档标注为「待审核」，RTL 仍在完善中。
- 仿真与验证：计划配套自校验 testbench 与 I2C / 音频主机模型（待补充）。

## 声明

本项目为基于公开数据手册的学习 / 研究实现，非德州仪器（TI）官方 IP，仅供技术交流与教育用途。

## License

本仓库仅用于学习研究，请勿用于商业产品。

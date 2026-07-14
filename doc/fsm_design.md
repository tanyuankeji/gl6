# TAS6424E-Q1 状态机设计文档

> **版本**: v1.0.0  
> **日期**: 2026-07-14  
> **状态**: 待审核  
> **关联文档**: `architecture_design_v2.md`，基于datasheet §9.4/§9.5

---

## 1. 状态机总览

芯片包含以下状态机：

| 状态机 | 模块 | 状态数 | 类型 | 描述 |
|--------|------|--------|------|------|
| 芯片主状态机 | state_machine | 5 | 两段式FSM | 控制芯片全局工作模式 |
| 通道状态机 ×4 | channel_fsm | 4 | 组合+时序 | 每通道独立状态控制 |
| I2C从机状态机 | i2c_slave | 9 | 两段式FSM | 标准I2C从机协议 |
| 诊断控制器状态机 | diagnostic_ctrl | 4 | 两段式FSM | DC/AC诊断流程控制 |

---

## 2. 芯片主状态机 (state_machine)

### 2.1 状态定义

```verilog
// 5个状态编码 (3位)
localparam CHIP_STANDBY = 3'd0;   // 待机: 振荡器停止, I2C活跃, 最低功耗
localparam CHIP_HI_Z    = 3'd1;   // 高阻: 输出FET关断, 振荡器运行
localparam CHIP_MUTE    = 3'd2;   // 静音: 输出FET 50%占空比开关
localparam CHIP_PLAY    = 3'd3;   // 播放: 输出FET PWM调制, 音频输出
localparam CHIP_DIAG    = 3'd4;   // 诊断: 通道诊断运行中
```

### 2.2 状态行为 (datasheet 表9-5)

| 状态 | 输出FET | 振荡器 | I2C | 说明 |
|------|---------|--------|-----|------|
| STANDBY | Hi-Z | 停止 | 活跃 | 电流<1µA (PVDD), <6µA (VBAT) |
| HI_Z | Hi-Z | 运行 | 活跃 | 等待命令, 可进入MUTE/PLAY/DIAG |
| MUTE | 50%占空比开关 | 运行 | 活跃 | 输出FET以50%占空比开关 |
| PLAY | 音频调制开关 | 运行 | 活跃 | 正常音频播放 |
| DIAG | 通道Hi-Z | 运行 (诊断需要时) | 活跃 | 运行DC/AC诊断 |

### 2.3 状态转换图

```
                        ┌──────────────────────────────────────────────────┐
                        │                                                  │
                        ▼                                                  │
                 ┌───────────────┐                                        │
            ┌───►│   STANDBY     │◄── standby_n==0 ───────────────────────┤
            │    │ (3'b000)      │                                        │
            │    └───────┬───────┘                                        │
            │            │ standby_n==1                                   │
            │            ▼                                                │
            │    ┌───────────────┐                                        │
            │    │     HI_Z      │◄── diag_done ─────────────────┐        │
            │    │  (3'b001)     │                                │        │
            │    └───────┬───────┘                                │        │
            │            │                                         │        │
            │     ┌──────┼──────┐                                  │        │
            │     │             │                                  │        │
            │     ▼             ▼                                  │        │
            │ ┌──────────┐ ┌──────────────┐                        │        │
            │ │   MUTE   │ │    PLAY      │                        │        │
            │ │ (3'b010) │ │  (3'b011)    │                        │        │
            │ └────┬─────┘ └──────┬───────┘                        │        │
            │      │              │                                │        │
            │      │ any_ch_diag==1                                │        │
            │      └──────┬───────┘                                │        │
            │             ▼                                         │        │
            │    ┌───────────────┐                                  │        │
            │    │     DIAG      │── diag_done ────────────────────┘        │
            │    │  (3'b100)     │                                         │
            │    └───────┬───────┘                                         │
            │            │                                                  │
            │            │ global_fault==1                                  │
            │            │                                                  │
            └────────────┼──────────────────────────────────────────────────│
                         │                                                  │
                         └─ clear_fault ─────────────────────────────────────┤
                           (清除故障后, 返回HI_Z或保持)                       │
                                                                             │
                    ┌───────────────────────────────────────────────────────┘
                    │
                    │ global_fault==1 (从任意非STANDBY状态)
                    ▼
              ┌───────────────┐
              │     HI_Z      │ (故障处理)
              │  (3'b001)     │
              └───────────────┘
```

### 2.4 状态转换条件详表

| # | 当前状态 | 下一状态 | 转换条件 | 优先级 |
|---|---------|---------|---------|--------|
| 1 | 任意 | STANDBY | `standby_n==0` | 最高 |
| 2 | 任意(非STANDBY) | HI_Z | `global_fault==1` | 高 |
| 3 | STANDBY | HI_Z | `standby_n==1 && !global_fault` | — |
| 4 | HI_Z | MUTE | `any_ch_mute==1 && !any_ch_play && !any_ch_diag` | — |
| 5 | HI_Z | PLAY | `any_ch_play==1 && !any_ch_diag` | — |
| 6 | HI_Z | DIAG | `any_ch_diag==1` | — |
| 7 | MUTE | PLAY | `any_ch_play==1 && !any_ch_diag` | — |
| 8 | MUTE | HI_Z | `all_ch_hiz==1` 或 `any_ch_diag==1` | — |
| 9 | PLAY | MUTE | `any_ch_mute==1 && !any_ch_play && !any_ch_diag` | — |
| 10 | PLAY | HI_Z | `all_ch_hiz==1` 或 `any_ch_diag==1` | — |
| 11 | DIAG | HI_Z | `diag_done==1` | — |
| 12 | DIAG | STANDBY | `standby_n==0` | 最高 |
| 13 | HI_Z | HI_Z | `global_fault==1` | 高 |
| 14 | HI_Z (故障) | HI_Z | `clear_fault==1` (故障已清除) | — |

### 2.5 关键组合信号生成

```verilog
// any_ch_play: 任意通道请求PLAY
assign any_ch_play = (ch_state_req[1:0] == CH_PLAY) ||
                     (ch_state_req[3:2] == CH_PLAY) ||
                     (ch_state_req[5:4] == CH_PLAY) ||
                     (ch_state_req[7:6] == CH_PLAY);

// any_ch_mute: 任意通道请求MUTE
assign any_ch_mute = (ch_state_req[1:0]   == CH_MUTE) ||
                     (ch_state_req[3:2] == CH_MUTE) ||
                     (ch_state_req[5:4] == CH_MUTE) ||
                     (ch_state_req[7:6] == CH_MUTE);

// any_ch_diag: 任意通道请求DC_DIAG
assign any_ch_diag = (ch_state_req[1:0]   == CH_DC_DIAG) ||
                     (ch_state_req[3:2] == CH_DC_DIAG) ||
                     (ch_state_req[5:4] == CH_DC_DIAG) ||
                     (ch_state_req[7:6] == CH_DC_DIAG);

// all_ch_hiz: 所有通道处于Hi-Z
assign all_ch_hiz = (ch_state_req[1:0]   == CH_HI_Z) &&
                    (ch_state_req[3:2] == CH_HI_Z) &&
                    (ch_state_req[5:4] == CH_HI_Z) &&
                    (ch_state_req[7:6] == CH_HI_Z);
```

### 2.6 state_machine模块接口

| 信号 | 位宽 | 方向 | 描述 |
|------|------|------|------|
| `clk` | 1 | I | 系统时钟 |
| `rst_n` | 1 | I | 异步复位 (低有效) |
| `standby_n` | 1 | I | STANDBY引脚 (经去抖同步) |
| `global_fault_irq` | 1 | I | 全局故障中断 (来自fault_monitor) |
| `clear_fault` | 1 | I | 清除故障 (来自reg 0x21 bit7) |
| `ch_state_req[7:0]` | 8 | I | 通道状态请求 (来自reg 0x04) |
| `diag_done` | 1 | I | 诊断完成 (来自diagnostic_ctrl) |
| `chip_state[2:0]` | 3 | O | 芯片当前状态 |
| `diag_trigger` | 1 | O | 诊断触发脉冲 (1 clk) |

### 2.7 RTL实现要点

```verilog
// 两段式FSM
// 第一段: 状态寄存器 (时序逻辑)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        chip_state <= CHIP_STANDBY;
    else
        chip_state <= chip_state_next;
end

// 第二段: 状态转换逻辑 (组合逻辑)
always @(*) begin
    chip_state_next = chip_state;  // 默认保持
    
    // 优先级1: STANDBY强制
    if (!standby_n)
        chip_state_next = CHIP_STANDBY;
    // 优先级2: 全局故障强制Hi-Z
    else if (global_fault_irq && (chip_state != CHIP_STANDBY))
        chip_state_next = CHIP_HI_Z;
    // 优先级3: 诊断触发
    else if (any_ch_diag && (chip_state == CHIP_MUTE || chip_state == CHIP_PLAY || chip_state == CHIP_HI_Z))
        chip_state_next = CHIP_DIAG;
    // 优先级4: 诊断完成
    else if (diag_done && chip_state == CHIP_DIAG)
        chip_state_next = CHIP_HI_Z;
    else begin
        case (chip_state)
            CHIP_STANDBY:
                if (standby_n && !global_fault_irq)
                    chip_state_next = CHIP_HI_Z;
            CHIP_HI_Z:
                if (any_ch_play && !any_ch_diag)
                    chip_state_next = CHIP_PLAY;
                else if (any_ch_mute && !any_ch_play && !any_ch_diag)
                    chip_state_next = CHIP_MUTE;
            CHIP_MUTE:
                if (all_ch_hiz)
                    chip_state_next = CHIP_HI_Z;
                else if (any_ch_play && !any_ch_diag)
                    chip_state_next = CHIP_PLAY;
            CHIP_PLAY:
                if (all_ch_hiz)
                    chip_state_next = CHIP_HI_Z;
                else if (any_ch_mute && !any_ch_play && !any_ch_diag)
                    chip_state_next = CHIP_MUTE;
            default: ;
        endcase
    end
end
```

---

## 3. 通道状态机 (channel_fsm × 4)

### 3.1 状态定义

```verilog
// 4个通道状态编码 (2位)
localparam CH_PLAY    = 2'b00;   // 播放: 正常PWM调制
localparam CH_HI_Z    = 2'b01;   // 高阻: 输出关断
localparam CH_MUTE    = 2'b10;   // 静音: 50%占空比
localparam CH_DC_DIAG = 2'b11;   // DC诊断: 输出关断, 测量负载
```

### 3.2 输出控制信号逻辑

| ch_state | ch_en | ch_mute_mode | ch_diag_active | PWM行为 |
|----------|-------|-------------|---------------|---------|
| CH_PLAY (00) | 1 | 0 | 0 | 音频调制PWM输出 |
| CH_HI_Z (01) | 0 | 0 | 0 | 输出强制为0 (Hi-Z) |
| CH_MUTE (10) | 1 | 1 | 0 | 50%占空比方波输出 |
| CH_DC_DIAG (11) | 0 | 0 | 1 | 输出关断, 等待诊断完成 |

### 3.3 状态转换图

```
                    ┌─────────────────────────────────────────────────┐
                    │                                                 │
                    ▼                                                 │
             ┌───────────────┐                                       │
        ┌───►│    HI_Z       │◄── ch_fault_latched ─────────────────┤
        │    │   (2'b01)     │                                       │
        │    └───────┬───────┘                                       │
        │            │                                               │
        │    chip_state==PLAY/MUTE                                   │
        │    ch_state_req==PLAY/MUTE                                 │
        │            │                                               │
        │     ┌──────┴──────┐                                        │
        │     ▼             ▼                                        │
        │ ┌──────────┐ ┌──────────────┐                                │
        │ │  PLAY    │ │    MUTE      │                                │
        │ │ (2'b00)  │ │  (2'b10)     │                                │
        │ └────┬─────┘ └──────┬───────┘                                │
        │      │              │                                        │
        │      │ ch_state_req==HI_Z                                   │
        │      └──────┬───────┘                                        │
        │             ▼                                                │
        │    ch_state_req==DC_DIAG                                     │
        │             │                                                │
        │             ▼                                                │
        │    ┌───────────────┐                                        │
        │    │   DC_DIAG     │── diag_done ──────────────────────────┤
        │    │  (2'b11)      │                                        │
        │    └───────┬───────┘                                        │
        │            │                                                │
        │            │ clear_fault (清除故障锁存)                      │
        │            │                                                │
        └────────────┼────────────────────────────────────────────────┘
                     │
                     │ chip_state==STANDBY
                     │ (全局待机, 强制Hi-Z)
                     │
                     └──► CH_HI_Z
```

### 3.4 状态转换条件

| 当前状态 | 下一状态 | 转换条件 |
|---------|---------|---------|
| CH_HI_Z | CH_PLAY | `chip_state==PLAY && ch_state_req==CH_PLAY && !ch_fault_latched` |
| CH_HI_Z | CH_MUTE | `chip_state==MUTE && ch_state_req==CH_MUTE && !ch_fault_latched` |
| CH_PLAY | CH_HI_Z | `ch_state_req==CH_HI_Z` 或 `chip_state==HI_Z` 或 `ch_fault_latched` |
| CH_MUTE | CH_HI_Z | `ch_state_req==CH_HI_Z` 或 `chip_state==HI_Z` 或 `ch_fault_latched` |
| CH_PLAY/MUTE | CH_DC_DIAG | `ch_state_req==CH_DC_DIAG` (chip_state变为DIAG) |
| CH_DC_DIAG | CH_HI_Z | `diag_done==1` |
| 任意 | CH_HI_Z | `chip_state==STANDBY` (全局强制) |

### 3.5 RTL实现要点

```verilog
// 每通道实例化
// 故障锁存: ch_fault锁存在fault_latch中
// clear_fault可清除锁存
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ch_fault_latched <= 1'b0;
    else if (clear_fault)
        ch_fault_latched <= 1'b0;
    else if (ch_fault_i)
        ch_fault_latched <= 1'b1;
end

// ch_en, ch_mute_mode, ch_diag_active为组合逻辑输出
always @(*) begin
    ch_en         = (ch_state == CH_PLAY) || (ch_state == CH_MUTE);
    ch_mute_mode  = (ch_state == CH_MUTE);
    ch_diag_active = (ch_state == CH_DC_DIAG);
end
```

---

## 4. I2C从机状态机 (i2c_slave)

### 4.1 状态定义

```verilog
localparam I2C_IDLE       = 4'd0;  // 空闲: 等待START条件
localparam I2C_ADDR       = 4'd1;  // 地址: 接收7位地址+R/W
localparam I2C_ACK_ADDR   = 4'd2;  // 地址确认: 发送ACK
localparam I2C_WR_ADDR    = 4'd3;  // 写子地址: 接收8位寄存器地址
localparam I2C_ACK_WA     = 4'd4;  // 子地址确认: 发送ACK
localparam I2C_WR_DATA    = 4'd5;  // 写数据: 接收8位数据
localparam I2C_ACK_WD     = 4'd6;  // 数据确认: 发送ACK
localparam I2C_RD_DATA    = 4'd7;  // 读数据: 发送8位数据
localparam I2C_ACK_RD     = 4'd8;  // 读确认: 接收主机ACK/NACK
```

### 4.2 状态转换图

```
                         ┌─────────────────────────────────────────────────┐
                         │                                                 │
  ┌───────┐ START ┌──────┴──┐ 8bit ┌──────────┐ ACK ┌──────────┐          │
  │ IDLE  │──────►│  ADDR   │─────►│ ACK_ADDR │────►│ WR_ADDR  │          │
  │ (4'd0)│       │ (4'd1)  │      │ (4'd2)   │     │ (4'd3)   │          │
  └───┬───┘       └─────────┘      └──────────┘     └────┬─────┘          │
      │                      ▲          ▲ R/W==1         │ ACK            │
      │ STOP                 │ NACK     │   (读)          ▼                │
      │                      │          │          ┌──────────┐           │
      └──────────┐      ┌────┴──────────┘          │ ACK_WA   │           │
                 │      │               │          │ (4'd4)   │           │
                 │      │               │◄─────────└────┬─────┘           │
                 │      │   读路径       │  8bit         │                 │
                 │      │               │◄──── ACK ─────┘                 │
                 │      │               │          ┌────▼─────┐           │
                 │      │               │ 8bit     │ WR_DATA  │           │
                 │      │               │◄─────────│ ACK_WD   │           │
                 │      │               │          │ (4'd5/6) │           │
                 │      │               │          └────┬─────┘           │
                 │      │               │               │ ACK + STOP      │
                 │      └───────────────┘               │                 │
                 │                                      ▼                 │
                 │ ┌───────┐ 8bit ┌──────────┐    ┌──────────┐           │
                 └►│RD_DATA│─────►│ ACK_RD   │    │  IDLE    │◄──────────┘
                   │(4'd7) │      │ (4'd8)   │    │ (4'd0)   │
                   └───┬───┘      └────┬─────┘    └──────────┘
                       │               │ ACK
                       │               ▼
                       │          ┌──────────┐
                       └──────────│ RD_DATA  │ (顺序读: 循环)
                                  └──────────┘
```

### 4.3 状态描述

| 状态 | 行为 | 下一状态条件 |
|------|------|------------|
| IDLE | 等待START条件 (SDA↓ while SCL=H) | 检测到START → ADDR |
| ADDR | 接收8位: 7位地址 + R/W位 | 地址匹配 → ACK_ADDR; 不匹配 → IDLE |
| ACK_ADDR | 发送ACK (拉低SDA 1个SCL周期) | R/W=0(写) → WR_ADDR; R/W=1(读) → RD_DATA |
| WR_ADDR | 接收8位寄存器子地址 | ACK → ACK_WA |
| ACK_WA | 发送ACK | 继续 → WR_DATA; STOP → IDLE |
| WR_DATA | 接收8位数据, 写入寄存器 | ACK → ACK_WD; NACK → IDLE |
| ACK_WD | 发送ACK | 继续(顺序写) → WR_DATA; STOP → IDLE |
| RD_DATA | 发送8位数据 (从寄存器读取) | 主机ACK → ACK_RD; NACK → IDLE |
| ACK_RD | 接收主机ACK/NACK | ACK → RD_DATA(顺序读); NACK+STOP → IDLE |

### 4.4 关键时序

- 在SCL高电平期间SDA下降沿检测START条件
- 在SCL高电平期间SDA上升沿检测STOP条件
- 在SCL低电平期间更新SDA数据（输出）
- 在SCL高电平期间采样SDA输入数据

### 4.5 子地址自增

```verilog
// 顺序读写时，子地址自动递增
// 到达0x79后回绕到0x00
if (sequential_access) begin
    subaddr <= (subaddr == 8'h79) ? 8'h00 : subaddr + 1'b1;
end
```

---

## 5. 诊断控制器状态机 (diagnostic_ctrl)

### 5.1 状态定义

```verilog
localparam DIAG_IDLE    = 2'b00;  // 空闲
localparam DIAG_DC_RUN  = 2'b01;  // DC诊断运行
localparam DIAG_AC_RUN  = 2'b10;  // AC诊断运行
localparam DIAG_DONE    = 2'b11;  // 诊断完成
```

### 5.2 状态转换图

```
         ┌───────────┐  diag_trigger   ┌─────────────┐
         │ DIAG_IDLE │────────────────►│ DIAG_DC_RUN │
         │  (2'b00)  │                 │  (2'b01)    │
         └─────▲─────┘                 └──────┬──────┘
               │                              │
               │                     timer_done (DC完成)
               │                              │
               │              ┌───────────────┘
               │              ▼
               │       ┌─────────────┐
               │       │  DIAG_DONE  │
               │       │  (2'b11)    │
               │       └──────┬──────┘
               │              │
               │       ┌──────┴──────────────────┐
               │       │                         │
               │       │ AC诊断使能?              │
               │       │ (ac_diag_en)             │
               │       ▼                         ▼
               │  ┌─────────────┐          ┌───────────┐
               │  │ DIAG_AC_RUN │          │  自动返回  │
               │  │  (2'b10)    │          │ DIAG_IDLE  │
               │  └──────┬──────┘          └───────────┘
               │         │
               │         │ timer_done (AC完成)
               │         │
               └─────────┘
```

### 5.3 诊断时序参数

| 参数 | 值 | 描述 |
|------|-----|------|
| DC诊断时间 (4通道) | ~230ms (typ) | datasheet §7.5 |
| AC诊断时间 (4通道) | ~520ms (typ) | datasheet §7.5 |
| 线路输出诊断时间 | ~40ms (typ) | datasheet §7.5 |
| RTL DIAG_TIMEOUT_CYCLES | 24'hFFFFF | ~100ms @10MHz (可调) |

### 5.4 诊断流程

**DC诊断流程**:
1. MCU写0x04寄存器 → 通道设为CH_DC_DIAG
2. state_machine检测 → DIAG态 → diag_trigger脉冲
3. diagnostic_ctrl → DIAG_DC_RUN, 启动计时器
4. 模拟前端施加测试电流，测量电压（RTL中为抽象建模）
5. 计时器到期 → 生成诊断报告 → 写入0x0C-0x0E
6. → DIAG_DONE → 1clk后 → DIAG_IDLE
7. diag_done → state_machine退出DIAG

**DC诊断结果编码** (每通道每项1位):

| 编码 | 测试项 | 含义 |
|------|--------|------|
| S2G | 对地短路 | 1=短路到GND (阻抗<200Ω) |
| S2P | 对电源短路 | 1=短路到PVDD (阻抗<500Ω) |
| OL | 开路 | 1=开路 (阻抗>40~70Ω) |
| SL | 负载短路 | 1=负载短路 (低于阈值) |

---

## 6. 设计检查清单

- [ ] 芯片主状态机5个状态是否完整覆盖datasheet表9-5
- [ ] standby_n最高优先级是否正确实现
- [ ] global_fault_irq是否在任何非STANDBY状态都强制回HI_Z
- [ ] 通道状态机的ch_fault_latched是否正确使用clear_fault清除
- [ ] I2C FSM是否正确处理START/STOP/RESTART条件
- [ ] I2C子地址自增是否正确回绕
- [ ] 诊断FSM在DIAG_DONE后是否正确返回DIAG_IDLE
- [ ] 诊断超时计数器是否可配置
- [ ] 所有FSM复位后是否回到正确的初始状态
- [ ] 是否避免了组合逻辑环路和锁存器

/**
 * Module: tas6424e_defines
 * Description: TAS6424E-Q1 全局参数定义文件
 *              包含寄存器地址、状态编码、时间常量等全局定义
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Changelog:
 *   v1.0.0 - 2026-07-11 - Initial release
 */

`ifndef TAS6424E_DEFINES_V
`define TAS6424E_DEFINES_V

//============================================================
// 芯片全局状态编码（主状态机）
//============================================================
`define CHIP_STANDBY   3'd0   // 待机：FETs高阻，振荡器关闭，I2C活跃
`define CHIP_HI_Z      3'd1   // Hi-Z：FETs高阻，振荡器工作
`define CHIP_MUTE      3'd2   // 静音：FETs 50%占空比开关
`define CHIP_PLAY      3'd3   // 播放：FETs音频调制开关
`define CHIP_DIAG      3'd4   // DC负载诊断态

//============================================================
// 通道状态编码（与0x04寄存器2位字段一致）
//============================================================
`define CH_PLAY        2'd0   // 播放模式
`define CH_HI_Z        2'd1   // 高阻态
`define CH_MUTE        2'd2   // 静音模式
`define CH_DC_DIAG     2'd3   // DC诊断模式

//============================================================
// 寄存器地址定义
//============================================================
`define REG_MODE_CTRL          8'h00   // 模式控制
`define REG_MISC_CTRL1         8'h01   // 杂项控制1
`define REG_MISC_CTRL2         8'h02   // 杂项控制2
`define REG_SAP_CTRL           8'h03   // 音频接口控制
`define REG_CH_STATE_CTRL      8'h04   // 通道状态控制
`define REG_CH1_VOL            8'h05   // 通道1音量
`define REG_CH2_VOL            8'h06   // 通道2音量
`define REG_CH3_VOL            8'h07   // 通道3音量
`define REG_CH4_VOL            8'h08   // 通道4音量
`define REG_DC_DIAG_CTRL1      8'h09   // DC诊断控制1
`define REG_DC_DIAG_CTRL2      8'h0A   // DC诊断控制2
`define REG_DC_DIAG_CTRL3      8'h0B   // DC诊断控制3
`define REG_DC_DIAG_RPT1       8'h0C   // DC诊断报告1
`define REG_DC_DIAG_RPT2       8'h0D   // DC诊断报告2
`define REG_DC_DIAG_RPT3       8'h0E   // DC诊断报告3
`define REG_CH_STATE_RPT       8'h0F   // 通道状态报告
`define REG_CH_FAULTS          8'h10   // 通道故障
`define REG_GLOBAL_FAULT1      8'h11   // 全局故障1
`define REG_GLOBAL_FAULT2      8'h12   // 全局故障2
`define REG_WARNINGS           8'h13   // 警告
`define REG_PIN_CTRL           8'h14   // 引脚控制
`define REG_AC_DIAG_CTRL1      8'h15   // AC诊断控制1
`define REG_AC_DIAG_CTRL2      8'h16   // AC诊断控制2
`define REG_AC_DIAG_RPT_CH1    8'h17   // AC诊断报告通道1
`define REG_AC_DIAG_RPT_CH2    8'h18   // AC诊断报告通道2
`define REG_AC_DIAG_RPT_CH3    8'h19   // AC诊断报告通道3
`define REG_AC_DIAG_RPT_CH4    8'h1A   // AC诊断报告通道4
`define REG_MISC_CTRL3         8'h21   // 杂项控制3（含CLEAR_FAULT）
`define REG_CLIP_CTRL          8'h22   // 削波控制
`define REG_CLIP_WINDOW        8'h23   // 削波窗口
`define REG_CLIP_WARNING       8'h24   // 削波警告
`define REG_ILIMIT_STATUS      8'h25   // 限流状态
`define REG_MISC_CTRL4         8'h26   // 杂项控制4
`define REG_MISC_CTRL5         8'h28   // 杂项控制5
`define REG_SS_CTRL1           8'h77   // 扩频控制1
`define REG_SS_CTRL2           8'h78   // 扩频控制2
`define REG_SS_CTRL3           8'h79   // 扩频控制3

//============================================================
// 寄存器默认值
//============================================================
`define DEF_MODE_CTRL          8'h00   // 0x00默认值
`define DEF_MISC_CTRL1         8'h32   // 0x01默认值
`define DEF_MISC_CTRL2         8'h62   // 0x02默认值
`define DEF_SAP_CTRL           8'h04   // 0x03默认值
`define DEF_CH_STATE_CTRL      8'h55   // 0x04默认值（所有通道Hi-Z）
`define DEF_CH_VOL             8'hCF   // 0x05-0x08默认值
`define DEF_CH_STATE_RPT       8'h55   // 0x0F默认值
`define DEF_CH_FAULTS          8'h00   // 0x10默认值
`define DEF_GLOBAL_FAULT1      8'h00   // 0x11默认值
`define DEF_GLOBAL_FAULT2      8'h00   // 0x12默认值
`define DEF_WARNINGS           8'h20   // 0x13默认值
`define DEF_PIN_CTRL           8'h00   // 0x14默认值
`define DEF_MISC_CTRL3         8'h00   // 0x21默认值
`define DEF_CLIP_CTRL          8'h01   // 0x22默认值
`define DEF_CLIP_WINDOW        8'h14   // 0x23默认值
`define DEF_CLIP_WARNING       8'h00   // 0x24默认值
`define DEF_ILIMIT_STATUS      8'h00   // 0x25默认值
`define DEF_MISC_CTRL4         8'h40   // 0x26默认值
`define DEF_MISC_CTRL5         8'h0A   // 0x28默认值

//============================================================
// 关键寄存器位域定义
//============================================================

// 0x00 Mode Control 位域
`define MODE_RESET_BIT         7       // 软件复位
`define MODE_PBTL_CH34_BIT     5       // 通道3/4 PBTL
`define MODE_PBTL_CH12_BIT     4       // 通道1/2 PBTL

// 0x01 Misc Control 1 位域
`define MISC1_HPF_BYPASS_BIT   7       // HPF旁路
`define MISC1_OTW_CTRL_HI      6       // OTW控制高字节
`define MISC1_OTW_CTRL_LO      5       // OTW控制低字节
`define MISC1_OC_CTRL_BIT      4       // OC控制
`define MISC1_VOL_RATE_HI      3       // 音量变化率高字节
`define MISC1_VOL_RATE_LO      2       // 音量变化率低字节
`define MISC1_GAIN_HI          1       // 增益高字节
`define MISC1_GAIN_LO          0       // 增益低字节

// 0x02 Misc Control 2 位域
`define MISC2_PWM_FREQ_HI      6       // PWM频率高字节
`define MISC2_PWM_FREQ_MID     5       // PWM频率中字节
`define MISC2_PWM_FREQ_LO      4       // PWM频率低字节
`define MISC2_SDM_OSR_BIT      2       // SDM过采样率

// 0x04 Channel State Control 位域
`define CH4_STATE_HI           7       // 通道4状态高字节
`define CH4_STATE_LO           6       // 通道4状态低字节
`define CH3_STATE_HI           5       // 通道3状态高字节
`define CH3_STATE_LO           4       // 通道3状态低字节
`define CH2_STATE_HI           3       // 通道2状态高字节
`define CH2_STATE_LO           2       // 通道2状态低字节
`define CH1_STATE_HI           1       // 通道1状态高字节
`define CH1_STATE_LO           0       // 通道1状态低字节

// 0x11 Global Faults 1 位域
`define GF1_INVALID_CLOCK_BIT  4       // 无效时钟
`define GF1_PVDD_OV_BIT        3       // PVDD过压
`define GF1_VBAT_OV_BIT        2       // VBAT过压
`define GF1_PVDD_UV_BIT        1       // PVDD欠压
`define GF1_VBAT_UV_BIT        0       // VBAT欠压

// 0x21 Misc Control 3 位域
`define MISC3_CLEAR_FAULT_BIT  7       // 清除故障
`define MISC3_OTSD_AUTO_RCV_BIT 3      // 过温自动恢复

//============================================================
// I2C地址定义（7位地址 + R/W位）
// 基地址0x6A，由i2c_addr1/addr0选择偏移
//============================================================
`define I2C_BASE_ADDR          7'b1101010   // 基地址0x6A

//============================================================
// 时间常量（以系统时钟周期为单位，假设系统时钟10MHz=100ns）
//============================================================
`define DEBOUNCE_CYCLES        16'd500     // 引脚去抖动周期（50us@10MHz）
`define CLK_TIMEOUT_CYCLES     20'hFFFFF   // 时钟丢失超时（~100ms@10MHz）
`define DIAG_TIMEOUT_CYCLES    20'h0FFFFF  // 诊断超时（~100ms@10MHz）
`define OTSD_RECOVERY_CYCLES   24'hFFFFFF  // 过温恢复冷却时间（~16s@10MHz）
`define FAULT_DEGLITCH_CYCLES  16'd100     // 故障去毛刺周期（10us@10MHz）

//============================================================
// PWM频率配置（0x02 bit[6:4]）
//============================================================
`define PWM_FREQ_2P1MHZ        3'b110   // 2.1MHz (44×fs@48kHz)

//============================================================
// 通道数
//============================================================
`define NUM_CHANNELS           4   // 4通道

`endif // TAS6424E_DEFINES_V

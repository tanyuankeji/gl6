// ============================================================================
// TAS6424E-Q1 故障监控器 (v6.0)
// 功能: 全局故障/通道故障/警告锁存 + 编码到寄存器格式 + 中断信号
// 设计原则:
//   - 锁存型故障: OV/UV/OTSD/OC/DC → 需clear_fault清除
//   - 非锁存型故障: OTW/POR/clock_lost → 自动恢复 (clock_lost除外也锁存)
//   - 全局故障中断 (global_fault) → channel_fsm强制Hi-Z
//   - 硬件写入寄存器: 0x10/0x11/0x12/0x13
// ============================================================================

module fault_monitor (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 清除
    input  wire         clear_fault,        // 0x21 bit7 清除故障
    // 保护后的故障信号 (已去毛刺, 来自protection)
    input  wire         otw_int,            // 全局过温警告
    input  wire         otsd_int,           // 全局过温关断
    input  wire [3:0]   otw_ch_int,         // 通道过温警告
    input  wire [3:0]   otsd_ch_int,        // 通道过温关断
    input  wire         vbat_uv_int,        // VBAT欠压
    input  wire         vbat_ov_int,        // VBAT过压
    input  wire         pvdd_uv_int,        // PVDD欠压
    input  wire         pvdd_ov_int,        // PVDD过压
    // 直接故障输入
    input  wire [3:0]   oc_ch,              // 通道过流
    input  wire [3:0]   dc_ch,              // 通道DC检测
    // 时钟/电源
    input  wire         clock_lost,         // 时钟丢失 (clock_monitor)
    input  wire         por_vdd,            // VDD POR
    // 故障输出
    output wire         global_fault_irq,   // 全局故障 (→channel_fsm强制Hi-Z)
    output wire [3:0]   ch_fault,           // CH1~4故障 (锁存)
    output wire         fault_trigger,      // FAULT引脚触发
    output wire         warn_trigger,       // WARN引脚触发
    // 硬件写 → 寄存器文件
    output reg  [7:0]   hw_ch_faults,       // 0x10: 通道故障
    output reg  [7:0]   hw_global_fault1,   // 0x11: 全局故障1
    output reg  [7:0]   hw_global_fault2,   // 0x12: 全局故障2
    output reg  [7:0]   hw_warnings,        // 0x13: 警告
    output reg          hw_wr_en,
    output reg  [7:0]   hw_wr_addr,
    output reg  [7:0]   hw_wr_data
);

    // ========================================================================
    // 故障锁存寄存器
    // ========================================================================
    reg [3:0] oc_latch;       // 通道过流锁存
    reg [3:0] dc_latch;       // 通道DC检测锁存
    reg [3:0] otsd_ch_latch;  // 通道OTSD锁存
    reg       pvdd_ov_latch, vbat_ov_latch;
    reg       pvdd_uv_latch, vbat_uv_latch;
    reg       otsd_global_latch;
    reg       clock_lost_latch;
    reg       por_latch;      // POR标志锁存

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {oc_latch, dc_latch, otsd_ch_latch} <= 12'd0;
            {pvdd_ov_latch, vbat_ov_latch, pvdd_uv_latch, vbat_uv_latch} <= 4'd0;
            otsd_global_latch <= 1'b0;
            clock_lost_latch  <= 1'b0;
            por_latch         <= 1'b0;
        end else if (clear_fault) begin
            {oc_latch, dc_latch, otsd_ch_latch} <= 12'd0;
            {pvdd_ov_latch, vbat_ov_latch, pvdd_uv_latch, vbat_uv_latch} <= 4'd0;
            otsd_global_latch <= 1'b0;
            clock_lost_latch  <= 1'b0;
            // POR不清除 (保持上报)
        end else begin
            // 锁存: 故障触发时置位
            oc_latch           <= oc_latch | oc_ch;
            dc_latch           <= dc_latch | dc_ch;
            otsd_ch_latch      <= otsd_ch_latch | otsd_ch_int;
            pvdd_ov_latch      <= pvdd_ov_latch | pvdd_ov_int;
            vbat_ov_latch      <= vbat_ov_latch | vbat_ov_int;
            pvdd_uv_latch      <= pvdd_uv_latch | pvdd_uv_int;
            vbat_uv_latch      <= vbat_uv_latch | vbat_uv_int;
            otsd_global_latch  <= otsd_global_latch | otsd_int;
            clock_lost_latch   <= clock_lost_latch | clock_lost;
            // POR锁存 (只置位, 只读上报)
            if (por_vdd) por_latch <= 1'b1;
        end
    end

    // ========================================================================
    // 故障信号输出
    // ========================================================================
    assign ch_fault = oc_latch | dc_latch | otsd_ch_latch;
    assign global_fault_irq = (|ch_fault) | pvdd_ov_latch | vbat_ov_latch
                            | pvdd_uv_latch | vbat_uv_latch
                            | otsd_global_latch | clock_lost_latch;
    assign fault_trigger = global_fault_irq;
    assign warn_trigger  = otw_int | por_latch | (|otw_ch_int);

    // ========================================================================
    // 寄存器编码 (硬件写入)
    // ========================================================================
    // 0x10: 通道故障
    wire [7:0] chf = {oc_latch[3:0], dc_latch[3:0]};
    // 0x11: 全局故障1
    wire [7:0] gf1 = {3'b000, clock_lost_latch, pvdd_ov_latch, vbat_ov_latch, pvdd_uv_latch, vbat_uv_latch};
    // 0x12: 全局故障2
    wire [7:0] gf2 = {3'b000, otsd_global_latch, otsd_ch_latch[3:0]};
    // 0x13: 警告
    wire [7:0] wn  = {2'b00, por_latch, otw_int, otw_ch_int[3:0]};

    // 边沿触发硬件写 (当任意寄存器值变化时)
    reg [31:0] hw_shadow;
    wire       hw_changed;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) hw_shadow <= 32'd0;
        else        hw_shadow <= {chf, gf1, gf2, wn};
    end
    assign hw_changed = ({chf, gf1, gf2, wn} != hw_shadow);

    // 硬件写状态机 (序列: 0x10→0x11→0x12→0x13→停止)
    reg [1:0] hw_seq;
    reg       seq_busy;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hw_wr_en   <= 1'b0;
            hw_seq     <= 2'd0;
            seq_busy   <= 1'b0;
        end else begin
            if (!seq_busy && hw_changed) begin
                // 启动序列
                seq_busy   <= 1'b1;
                hw_wr_en   <= 1'b1;
                hw_wr_addr <= 8'h10;
                hw_wr_data <= chf;
                hw_seq     <= 2'd1;
            end else if (seq_busy) begin
                case (hw_seq)
                    2'd1: begin hw_wr_en <= 1'b1; hw_wr_addr <= 8'h11; hw_wr_data <= gf1; hw_seq <= 2'd2; end
                    2'd2: begin hw_wr_en <= 1'b1; hw_wr_addr <= 8'h12; hw_wr_data <= gf2; hw_seq <= 2'd3; end
                    2'd3: begin
                        hw_wr_en <= 1'b1; hw_wr_addr <= 8'h13; hw_wr_data <= wn;
                        hw_seq   <= 2'd0;
                        seq_busy <= 1'b0;  // 序列完成, 回到idle
                    end
                    default: seq_busy <= 1'b0;
                endcase
            end else begin
                hw_wr_en <= 1'b0;
                seq_busy <= 1'b0;
            end
        end
    end

    // 异步更新输出
    always @(posedge clk) begin
        if (hw_changed || hw_seq != 2'd3) begin
            hw_ch_faults    <= chf;
            hw_global_fault1 <= gf1;
            hw_global_fault2 <= gf2;
            hw_warnings     <= wn;
        end
    end

endmodule

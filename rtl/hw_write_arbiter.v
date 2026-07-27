// ============================================================================
// TAS6424E-Q1 硬件写仲裁器
// 功能: 3路硬件写源优先级仲裁, 写入register_file
// 设计: ch_state(0x0F) > diag(dc+ac合并) > fault_monitor
// ============================================================================

module hw_write_arbiter (
    // ch_state (0x0F 通道状态上报)
    input  wire       ch_state_wr_en,
    input  wire [7:0] ch_state_wr_addr,
    input  wire [7:0] ch_state_wr_data,
    // diag (DC + AC 诊断合并)
    input  wire       diag_hw_en,
    input  wire [7:0] diag_hw_addr,
    input  wire [7:0] diag_hw_data,
    // fault_monitor
    input  wire       fault_hw_en,
    input  wire [7:0] fault_hw_addr,
    input  wire [7:0] fault_hw_data,
    // 仲裁输出
    output wire       hw_wr_en,
    output wire [7:0] hw_wr_addr,
    output wire [7:0] hw_wr_data
);

    wire [1:0] hw_sel;
    assign hw_sel = ch_state_wr_en ? 2'd1
                  : diag_hw_en     ? 2'd2
                  : fault_hw_en    ? 2'd3 : 2'd0;

    assign hw_wr_en   = (hw_sel != 2'd0);
    assign hw_wr_addr = (hw_sel == 2'd1) ? ch_state_wr_addr
                      : (hw_sel == 2'd2) ? diag_hw_addr : fault_hw_addr;
    assign hw_wr_data = (hw_sel == 2'd1) ? ch_state_wr_data
                      : (hw_sel == 2'd2) ? diag_hw_data : fault_hw_data;

endmodule

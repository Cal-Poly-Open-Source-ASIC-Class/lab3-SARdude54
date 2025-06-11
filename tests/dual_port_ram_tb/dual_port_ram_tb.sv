`timescale 1ns/1ps

module dual_port_ram_tb;

    // Clock
    logic clk = 0;
    logic rst_n;
    always #5 clk = ~clk;

    // Port A signals
    logic [8:0]  pA_addr;
    logic        pA_we, pA_cyc, pA_stb;
    logic [31:0] pA_data_in;
    logic [3:0]  pA_sel;
    wire  [31:0] pA_data_out;
    wire         pA_ack, pA_stall;

    // Port B signals
    logic [8:0]  pB_addr;
    logic        pB_we, pB_cyc, pB_stb;
    logic [31:0] pB_data_in;
    logic [3:0]  pB_sel;
    wire  [31:0] pB_data_out;
    wire         pB_ack, pB_stall;

    // DUT instantiation
    dual_port_ram dut (
        .clk(clk),
        .rst_n(rst_n),
        // Port A
        .pA_wb_addr_i(pA_addr),
        .pA_wb_we_i(pA_we),
        .pA_wb_cyc_i(pA_cyc),
        .pA_wb_stb_i(pA_stb),
        .pA_wb_data_i(pA_data_in),
        .pA_wb_sel_i(pA_sel),
        .pA_wb_data_o(pA_data_out),
        .pA_wb_ack_o(pA_ack),
        .pA_wb_stall_o(pA_stall),
        // Port B
        .pB_wb_addr_i(pB_addr),
        .pB_wb_we_i(pB_we),
        .pB_wb_cyc_i(pB_cyc),
        .pB_wb_stb_i(pB_stb),
        .pB_wb_data_i(pB_data_in),
        .pB_wb_sel_i(pB_sel),
        .pB_wb_data_o(pB_data_out),
        .pB_wb_ack_o(pB_ack),
        .pB_wb_stall_o(pB_stall)
    );

    // signal cycle write procedure
    task write(
    input logic port_sel,
    input logic [8:0] addr,
    input logic [31:0] data
);
    // port A write 
    if (port_sel == 0) begin
        pA_addr = addr; 
        pA_data_in = data;

        pA_sel = 4'b1111;

        pA_we = 1; pA_stb = 1; pA_cyc = 1;

        do @(posedge clk); while (pA_stall);

        wait(pA_ack); @(posedge clk);

        pA_we = 0; pA_stb = 0; pA_cyc = 0;

    // port B write
    end else begin
        pB_addr = addr; 
        pB_data_in = data;

        pB_sel = 4'b1111;

        pB_we = 1; pB_stb = 1; pB_cyc = 1;

        do @(posedge clk); while (pB_stall);
        
        wait(pB_ack); @(posedge clk);
        pB_we = 0; pB_stb = 0; pB_cyc = 0;
    end
endtask


    // signal cycle read procedure
    task read(
        input logic port_sel,
        input logic [8:0] addr,
        output logic [31:0] data
    );
        if (port_sel == 0) begin
            pA_addr = addr;
            pA_sel = 4'b1111; pA_we = 0; pA_stb = 1; pA_cyc = 1;
            wait(pA_ack);            // wait for acknowledge
            @(posedge clk);          // wait fo data stabilize
            @(posedge clk);
            data = pA_data_out;      // get data
            @(posedge clk);
            pA_stb = 0; pA_cyc = 0;
        end else begin
            pB_addr = addr;
            pB_sel = 4'b1111; pB_we = 0; pB_stb = 1; pB_cyc = 1;
            wait(pB_ack);
            @(posedge clk); 
            @(posedge clk);
            data = pB_data_out;
            @(posedge clk);
            pB_stb = 0; pB_cyc = 0;
        end
    endtask



    logic [31:0] rd_data;
    initial begin
        $dumpfile("dual_port_ram_tb.vcd");
        $dumpvars(0, dual_port_ram_tb);

        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        @(posedge clk);

        // #100
        // $display("Test Passed");
        // $finish;
    end


    // Test Conflict
    // Port A
    always begin

        // Non Conflict
        // Write to RAM A via Port A
        write(0, 9'h012, 32'hDEADBEEF);

        // Read back from RAM A via Port A
        read(0, 9'h012, rd_data);
        assert(rd_data == 32'hDEADBEEF) else $fatal(1, "RAM A Read Error");

        // Conflict
        repeat(2) @(posedge clk);
        write(0, 9'h03F, 32'hAAAAAAAA);  // Port A -> RAM A
        
        read(0, 9'h03F, rd_data);
        assert(rd_data == 32'hAAAAAAAA) else $fatal(1, "Conflict Write A Error");

        $finish;
    end
    // Port B
    always begin

        // non-conflict
        // Write to RAM B via Port B
        write(1, 9'h192, 32'hCAFEBABE);
        
        // Read back from RAM B via Port B
        read(1, 9'h192, rd_data);
        assert(rd_data == 32'hCAFEBABE) else $fatal(1, "RAM B Read Error");

        // conflict
        repeat(2) @(posedge clk);
        write(1, 9'h03F, 32'hAAAAAAAA);  // Port B -> RAM A

        read(1, 9'h01F, rd_data);
        assert(rd_data == 32'hBBBBBBBB) else $fatal(1, "Conflict Write B Error");
    $finish;
    end
endmodule


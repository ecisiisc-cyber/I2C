//`timescale 1ns / 1ps

//module tb;
//    reg clk_tb;
//    reg reset_tb;
//    event reset_done;

//    // Clock Gen
//    always #5 clk_tb = ~clk_tb;

//    initial begin 
//        clk_tb = 0;
//        reset_tb = 1;
//        repeat (5) @(posedge clk_tb); 
//        reset_tb = 0;
//        ->reset_done;
//    end 

//    reg run;
//    initial begin 
//        run = 0;
//        @(reset_done);
//        repeat(5) @(posedge clk_tb);
//        run = 1;
//    end

//    // Signal Declarations
//    reg [3:0] state; // Changed to 4-bit to match your parameters
//    parameter idle=0, tx1=1, tx2=2, stop=3;

//    reg [15:0] reg_addr_tb;
//    reg [7:0] write_data_tb;
//    reg read_tb, write_tb, start_tb;
    
//    wire done_tb, scl_tb, sda_tb;
//    wire [7:0] read_data;

//    // MANDATORY I2C PULL-UPS
//    pullup(scl_tb);
//    pullup(sda_tb);

//    always @(posedge clk_tb) begin 
//        if (!run) begin 
//            reg_addr_tb   <= 0;
//            write_data_tb <= 0;
//            read_tb       <= 0;
//            write_tb      <= 0;
//            start_tb      <= 0;
//            state         <= idle;
//        end else begin 
//            case(state)
//                idle: state <= tx1;

//                tx1: begin 
//                    reg_addr_tb   <= 16'h55FF;
//                    write_data_tb <= 8'hAA;
//                    start_tb      <= 1;
//                    write_tb      <= 1; 
//                    if(done_tb) state <= tx2;
//                end

//                tx2: begin 
//                    start_tb      <= 0; // Pulse start low then high to trigger next
//                    if(!done_tb) begin
//                        start_tb      <= 1;
//                        reg_addr_tb   <= 16'h1234;
//                        write_data_tb <= 8'h56;
//                        if(done_tb) state <= stop;
//                    end
//                end

//                stop: begin 
//                    start_tb <= 0;
//                    write_tb <= 0;
//                    state    <= stop;
//                    $display("Simulation Finished Successfully");
//                    $finish; // Stop simulation
//                end
//            endcase
//        end
//    end

//    mcp16701_write dut (
//        .clk(clk_tb),
//        .reset(reset_tb),
//        .start(start_tb),
//        .read(read_tb),
//        .write(write_tb),
//        .reg_addr(reg_addr_tb),
//        .write_data(write_data_tb),
//        .read_data(read_data),
//        .done(done_tb),
//        .scl(scl_tb),
//        .sda(sda_tb)
//    );

//endmodule


`timescale 1ns / 1ps

module tb;
    // 1. Declare Signals
    reg clk_tb;
    reg reset_tb;
    reg start_tb, read_tb, write_tb;
    reg [15:0] reg_addr_tb;
    reg [7:0] write_data_tb;

    wire [7:0] read_data;
    wire done_tb, scl_tb;
    wire sda_tb;
    reg drive_en;
    assign sda_tb=drive_en?0:1'bz;

    // 2. MANDATORY: I2C Pull-up Resistors
    // Without these, the 'tri' lines in your code stay at 'Z' (High Impedance)
    pullup(scl_tb);
    pullup(sda_tb);

    // 3. Clock Generation (100MHz)
    always #5 clk_tb = ~clk_tb;

    // 4. Instantiate the DUT
    mcp16701_write dut (
        .clk(clk_tb),
        .reset(reset_tb),
        .start(start_tb),
        .read(read_tb),
        .write(write_tb),
        .reg_addr(reg_addr_tb),
        .write_data(write_data_tb),
        .read_data(read_data),
        .done(done_tb),
        .scl(scl_tb),
        .sda(sda_tb)
    );

    // 5. The Test Sequence
    initial begin
        // Initialize everything
        drive_en=0;
        clk_tb = 0;
        reset_tb = 1;
        start_tb = 0;
        read_tb = 0;
        write_tb = 0;
        reg_addr_tb = 16'h0000;
        write_data_tb = 8'h00;

        // Release Reset after 100ns
        #100 reset_tb = 0;
        #100;
        repeat(5000) @(posedge clk_tb);

        // Trigger ONE Write Transaction
        @(posedge clk_tb);
        reg_addr_tb   = 16'h55FF; // Example Address
        write_data_tb = 8'hAA;    // Example Data
        write_tb      = 1;        // Set to Write mode
        start_tb      = 1;        // Pulse Start
        
        @(posedge clk_tb);
        start_tb = 0;             // Clear Start so it doesn't repeat
        
        //second write
        @(done_tb);
        repeat(5000) @(posedge clk_tb);
        reg_addr_tb   = 16'h1234; // Example Address
        write_data_tb = 8'h56;    // Example Data
        write_tb      = 1;        // Set to Write mode
        start_tb      = 1;        // Pulse Start
        @(posedge clk_tb);
         start_tb = 0;     
         write_tb=0;
         //first read
        @(done_tb);
         repeat(5000) @(posedge clk_tb);
         reg_addr_tb   = 16'hABCD; // Example Address
         write_data_tb = 8'hEF;    // Example Data
         read_tb      = 1;        // Set to read mode
         start_tb      = 1;        // Pulse Start
         @(posedge clk_tb);
          start_tb = 0;     
          wait(dut.state==8);
          drive_en=1;
          repeat(2)@(negedge scl_tb);
          drive_en=0;

        // 6. Wait for the Master to finish
        // I2C is SLOW. At 100MHz with dvsr=250, one byte takes ~10,000ns.
        // A full transaction (4 bytes) takes ~50,000ns.
        wait(done_tb == 1);
        
        $display("SUCCESS: Transaction Finished at %t", $time);
        #1000;
        $finish;
    end
    
    wire ready_tb ;
    assign ready_tb=dut.ready;
    wire[3:0] state_i2ctransaction;
    assign state_i2ctransaction=dut.i2c0.state_reg;
    wire [15:0] c_reg_tb;
    assign c_reg_tb=dut.i2c0.c_reg;
    wire [15:0] half_tb;
    assign half_tb=dut.i2c0.half;
    wire [2:0] cmd_tb;
    assign cmd_tb=dut.i2c0.cmd;
    

endmodule
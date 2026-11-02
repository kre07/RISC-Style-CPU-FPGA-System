module alu_tb;

    reg [31:0] a;
    reg [31:0] b;
    reg [3:0] alu_op;

    wire [31:0] result;
    wire zero;

    // ALU we are testing
    alu dut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result),
        .zero(zero)
    );

    initial begin

        // Test ADD: 5 + 3 = 8
        a = 32'd5;
        b = 32'd3;
        alu_op = 4'b0000;
        #10;

        if (result == 32'd8)
            $display("ADD PASS");
        else
            $display("ADD FAIL");

        // Test SUB: 5 - 3 = 2
        a = 32'd5;
        b = 32'd3;
        alu_op = 4'b0001;
        #10;

        if (result == 32'd2)
            $display("SUB PASS");
        else
            $display("SUB FAIL");

        $stop;

    end

endmodule

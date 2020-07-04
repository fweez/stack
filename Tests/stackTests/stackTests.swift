import XCTest
@testable import stack

final class stackTests: XCTestCase {
    func testConst() {
        XCTAssertEqual(Machine(instructions: [.const(3)]).run().stack, [3])
        XCTAssertEqual(Machine(instructions: [.const(3), .const(4)]).run().stack, [4, 3])
    }
    
    func testRawConsts() {
        XCTAssertEqual(Machine(instructions: [3, 4]).run().stack, [4, 3])
    }
    
    func testAdd() {
        XCTAssertEqual(Machine(instructions: [3, 4, .add]).run().stack, [7])
    }
    
    func testAsFunctionBuilder() {
        let m = Machine {
            4
            3
            Instruction.add
        }
            .run()
        
        XCTAssertEqual(m.stack, [7])
    }
}


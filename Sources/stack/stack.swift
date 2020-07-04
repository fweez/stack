enum Value: ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral {
    case int(Int)
    case bool(Bool)
    
    public init(integerLiteral value: IntegerLiteralType) {
        self = .int(value)
    }
    
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
    
    var description: String {
        switch self {
        case .int(let v): return "\(v)"
        case .bool(let v): return "\(v)"
        }
    }
    
    var asInt: Int? {
        switch self {
        case .int(let v): return v
        default: return nil
        }
    }
    
    var asBool: Bool? {
        switch self {
        case .bool(let v): return v
        default: return nil
        }
    }
}

extension Value: Equatable {
    static func ==(lhs: Value, rhs: Value) -> Bool {
        switch (lhs, rhs) {
        case (.int(let l), .int(let r)): return l == r
        case (.bool(let l), .bool(let r)): return l == r
        default: return false
        }
    }
}

enum Instruction: Equatable, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral {
    case const(Value)
    case add
    case exit
    case mod
    case print
    case eq
    case error(Any)
    
    public init(integerLiteral value: IntegerLiteralType) {
        self = .const(Value(integerLiteral: value))
    }
    
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .const(Value(booleanLiteral: value))
    }
    
    static func ==(lhs: Instruction, rhs: Instruction) -> Bool {
        switch (lhs, rhs) {
        case (.const(let a), .const(let b)): return a == b
        case (.add, .add),
             (.exit, .exit),
             (.mod, .mod),
             (.print, .print),
             (.eq, .eq): return true
        default: return false
        }
    }
}

struct Machine {
    enum StackError: Error {
        case finished(Machine)
        case typeError
        case stackUnderflow
        case unexpectedlyEmptyInstructions
    }
    
    var stack: [Value] = []
    var slots: [Int] = Array(repeating: 0, count: 10)
    var instructions: [Instruction]
    
    func run() -> Machine {
        switch step() {
        case .success(let newMachine): return newMachine.run()
        case .failure(.finished(let finishedMachine)): return finishedMachine
        case .failure(let err):
            print(err)
            return self
        }
    }
    
    func step() -> Result<Machine, StackError> {
        next()
            .flatMap { next, machine in
                machine.execute(next)
            }
    }
    
    fileprivate func add() -> Result<Machine, Machine.StackError> {
        return pop(2)
            .flatMap { values, machine in
                guard let a = values.first?.asInt, let b = values.last?.asInt else { return .failure(.typeError) }
                return .success(machine.push(.int(a + b)))
        }
    }
    
    fileprivate func mod() -> Result<Machine, Machine.StackError> {
        return pop(2)
            .flatMap { values, machine in
                guard let a = values.first?.asInt, let b = values.last?.asInt else { return .failure(.typeError) }
                return .success(machine.push(.int(a % b)))
        }
    }
    
    fileprivate func eq() -> Result<Machine, Machine.StackError> {
        return pop(2)
            .flatMap { values, machine in
                guard let a = values.first, let b = values.last  else {
                    return .failure(.stackUnderflow)
                }
                return .success(machine.push(.bool(a == b)))
        }
    }
    
    func execute(_ instruction: Instruction) -> Result<Machine, StackError> {
        switch instruction {
        case .const(let c): return .success(push(c))
        case .exit: return .success(self)
        case .error(let val): fatalError("Unknown instruction \(val)")
        case .print:
            print(stack.first?.description ?? "--no value--")
            return .success(self)
        case .add: return add()
        case .mod: return mod()
        case .eq: return eq()
        }
    }
    
    public init(@InstructionBuilder content: () -> [Instruction]) {
        instructions = content()
    }
    
    public init(stack: [Value] = [], slots: [Int] = [], instructions: [Instruction]) {
        self.stack = stack
        self.slots = slots
        self.instructions = instructions
    }
    
    private func next() -> Result<(Instruction, Machine), StackError> {
        guard let next = instructions.first else { return .failure(.unexpectedlyEmptyInstructions) }
        return .success(
            (next,
             .init(
                stack: stack,
                slots: slots,
                instructions: Array(instructions.suffix(from: 1)))))
    }
    
    private func pop(_ count: Int) -> Result<([Value], Machine), StackError> {
        guard stack.count >= count else { return .failure(.stackUnderflow) }
        return .success((
            Array(stack.prefix(count)),
            .init(stack: Array(stack.suffix(from: 2)), slots: slots, instructions: instructions)))
    }
    
    private func push(_ value: Value) -> Machine {
        return .init(stack: [value] + stack, slots: slots, instructions: instructions)
    }
}

@_functionBuilder
public struct InstructionBuilder {
    static func buildBlock(_ children: Any...) -> [Instruction] {
        children.map { child -> Instruction in
            if let child = child as? Instruction { return child }
            if let child = child as? Int { return .const(Value(integerLiteral: child)) }
            if let child = child as? Bool { return .const(Value(booleanLiteral: child)) }
            return .error(child)
        }
    }
}

local inspect = require('lib/inspect')
local Memory = Core.Memory
local CPU = Core.CPU

-- print(inspect(Core))
-- print(Memory:peek(0x69))
-- print(CPU:writeRegister(CPU.AF, 0xFFFF))
-- print(CPU:getRegister(CPU.AF))

function Core.step()
  io.write("\rHL="..CPU:getRegister(CPU.HL))
end
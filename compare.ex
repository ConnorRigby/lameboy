Mix.install([:circular_buffer])

defmodule Compare do
  @opcodetable [
    "NOP",
    "LD BC,d16",
    "LD (BC),A",
    "INC BC",
    "INC B",
    "DEC B",
    "LD B,d8",
    "RLCA",
    "LD (a16),SP",
    "ADD HL,BC",
    "LD A,(BC)",
    "DEC BC",
    "INC C",
    "DEC C",
    "LD C,d8",
    "RRCA",
    "STOP 0",
    "LD DE,d16",
    "LD (DE),A",
    "INC DE",
    "INC D",
    "DEC D",
    "LD D,d8",
    "RLA",
    "JR r8",
    "ADD HL,DE",
    "LD A,(DE)",
    "DEC DE",
    "INC E",
    "DEC E",
    "LD E,d8",
    "RRA",
    "JR NZ,r8",
    "LD HL,d16",
    "LD (HL+),A",
    "INC HL",
    "INC H",
    "DEC H",
    "LD H,d8",
    "DAA",
    "JR Z,r8",
    "ADD HL,HL",
    "LD A,(HL+)",
    "DEC HL",
    "INC L",
    "DEC L",
    "LD L,d8",
    "CPL",
    "JR NC,r8",
    "LD SP,d16",
    "LD (HL-),A",
    "INC SP",
    "INC (HL)",
    "DEC (HL)",
    "LD (HL),d8",
    "SCF",
    "JR C,r8",
    "ADD HL,SP",
    "LD A,(HL-)",
    "DEC SP",
    "INC A",
    "DEC A",
    "LD A,d8",
    "CCF",
    "LD B,B",
    "LD B,C",
    "LD B,D",
    "LD B,E",
    "LD B,H",
    "LD B,L",
    "LD B,(HL)",
    "LD B,A",
    "LD C,B",
    "LD C,C",
    "LD C,D",
    "LD C,E",
    "LD C,H",
    "LD C,L",
    "LD C,(HL)",
    "LD C,A",
    "LD D,B",
    "LD D,C",
    "LD D,D",
    "LD D,E",
    "LD D,H",
    "LD D,L",
    "LD D,(HL)",
    "LD D,A",
    "LD E,B",
    "LD E,C",
    "LD E,D",
    "LD E,E",
    "LD E,H",
    "LD E,L",
    "LD E,(HL)",
    "LD E,A",
    "LD H,B",
    "LD H,C",
    "LD H,D",
    "LD H,E",
    "LD H,H",
    "LD H,L",
    "LD H,(HL)",
    "LD H,A",
    "LD L,B",
    "LD L,C",
    "LD L,D",
    "LD L,E",
    "LD L,H",
    "LD L,L",
    "LD L,(HL)",
    "LD L,A",
    "LD (HL),B",
    "LD (HL),C",
    "LD (HL),D",
    "LD (HL),E",
    "LD (HL),H",
    "LD (HL),L",
    "HALT",
    "LD (HL),A",
    "LD A,B",
    "LD A,C",
    "LD A,D",
    "LD A,E",
    "LD A,H",
    "LD A,L",
    "LD A,(HL)",
    "LD A,A",
    "ADD A,B",
    "ADD A,C",
    "ADD A,D",
    "ADD A,E",
    "ADD A,H",
    "ADD A,L",
    "ADD A,(HL)",
    "ADD A,A",
    "ADC A,B",
    "ADC A,C",
    "ADC A,D",
    "ADC A,E",
    "ADC A,H",
    "ADC A,L",
    "ADC A,(HL)",
    "ADC A,A",
    "SUB B",
    "SUB C",
    "SUB D",
    "SUB E",
    "SUB H",
    "SUB L",
    "SUB (HL)",
    "SUB A",
    "SBC A,B",
    "SBC A,C",
    "SBC A,D",
    "SBC A,E",
    "SBC A,H",
    "SBC A,L",
    "SBC A,(HL)",
    "SBC A,A",
    "AND B",
    "AND C",
    "AND D",
    "AND E",
    "AND H",
    "AND L",
    "AND (HL)",
    "AND A",
    "XOR B",
    "XOR C",
    "XOR D",
    "XOR E",
    "XOR H",
    "XOR L",
    "XOR (HL)",
    "XOR A",
    "OR B",
    "OR C",
    "OR D",
    "OR E",
    "OR H",
    "OR L",
    "OR (HL)",
    "OR A",
    "CP B",
    "CP C",
    "CP D",
    "CP E",
    "CP H",
    "CP L",
    "CP (HL)",
    "CP A",
    "RET NZ",
    "POP BC",
    "JP NZ,a16",
    "JP a16",
    "CALL NZ,a16",
    "PUSH BC",
    "ADD A,d8",
    "RST 00H",
    "RET Z",
    "RET",
    "JP Z,a16",
    "PREFIX CB",
    "CALL Z,a16",
    "CALL a16",
    "ADC A,d8",
    "RST 08H",
    "RET NC",
    "POP DE",
    "JP NC,a16",
    "INV",
    "CALL NC,a16",
    "PUSH DE",
    "SUB d8",
    "RST 10H",
    "RET C",
    "RETI",
    "JP C,a16",
    "INV",
    "CALL C,a16",
    "INV",
    "SBC A,d8",
    "RST 18H",
    "LDH (a8),A",
    "POP HL",
    "LD (C),A",
    "INV",
    "INV",
    "PUSH HL",
    "AND d8",
    "RST 20H",
    "ADD SP,r8",
    "JP (HL)",
    "LD (a16),A",
    "INV",
    "INV",
    "INV",
    "XOR d8",
    "RST 28H",
    "LDH A,(a8)",
    "POP AF",
    "LD A,(C)",
    "DI",
    "INV",
    "PUSH AF",
    "OR d8",
    "RST 30H",
    "LD HL,SP+r8",
    "LD SP,HL",
    "LD A,(a16)",
    "EI",
    "INV",
    "INV",
    "CP d8",
    "RST 38H"
  ]
  def run(one, two) do
    left = File.read!(one) |> String.trim() |> String.split("\n")
    right = File.read!(two) |> String.trim() |> String.split("\n")
    compare(left, right, 1, CircularBuffer.new(5), nil)
  end

  def compare([line | rest_left], [line | rest_right], linenumber, buffer, nil) do
    compare(rest_left, rest_right, linenumber + 1, CircularBuffer.insert(buffer, line), nil)
  end

  def compare(_, _, _, _, 0) do
    :ok
  end

  def compare([line | rest_left], [line | rest_right], linenumber, buffer, continue) do
    dc(line)
    |> highlight()
    |> IO.puts()

    compare(
      rest_left,
      rest_right,
      linenumber + 1,
      CircularBuffer.insert(buffer, line),
      continue - 1
    )
  end

  def compare([left | rest_left], [right | rest_right], linenumber, buffer, nil) do
    list = CircularBuffer.to_list(buffer)
    all = list |> Enum.map(fn line -> dc(line) |> highlight() end)
    last = Enum.drop(all, -1)
    special = List.last(list, 0)
    last = last ++ [dc(special) |> highlight(:special)]
    continue = Enum.count(last)
    last = last |> Enum.join("\n")
    # last = dc(last) |> highlight()
    left = dc(left)
    right = dc(right)
    {left, right} = diff(left, right, [], [])
    left = highlight(left)
    right = highlight(right)

    IO.puts("divergence on line: #{linenumber}\n\n#{last}\n#{left}[got]\n#{right}[expected]")
    compare(rest_left, rest_right, linenumber + 1, buffer, continue)
  end

  def compare([left | rest_left], [right | rest_right], linenumber, buffer, continue) do
    {left, right} = diff(dc(left), dc(right), [], [])
    left = highlight(left)
    right = highlight(right)
    IO.puts("#{left}[diverged]\n#{right}[diverged]")
    compare(rest_left, rest_right, linenumber + 1, buffer, continue - 1)
  end

  def highlight(line, special \\ false) do
    [a, f, b, c, d, e, h, l, sp, pc, pc0, pc1, pc2, pc3] =
      Enum.map(line, fn
        {:diff, {:f, value}} ->
          value = String.to_integer(value, 16)
          # <<0::4, c::1,h::1,n::1,z::1>> = <<value::8>>
          <<z::1, n::1, h::1, c::1, unused::4>> = <<value::8>>

          [
            IO.ANSI.red(),
            "#{c}#{h}#{n}#{z}#{if unused != 0, do: "[F is invalid: #{inspect(unused, base: :binary)}]"}",
            IO.ANSI.white()
          ]

        {:diff, {_type, value}} ->
          [IO.ANSI.red(), value, IO.ANSI.white()]

        {type, value} when type == :f ->
          value = String.to_integer(value, 16)
          # <<0::4, c::1,h::1,n::1,z::1>> = <<value::8>>
          <<z::1, n::1, h::1, c::1, unused::4>> = <<value::8>>

          [
            IO.ANSI.cyan(),
            "#{c}#{h}#{n}#{z}#{if unused != 0, do: "[F is invalid: #{inspect(unused, base: :binary)}]"}",
            IO.ANSI.white()
          ]

        {type, value} when type in [:a, :b, :c, :d, :e, :h, :l] ->
          [IO.ANSI.cyan(), value, IO.ANSI.white()]

        {type, value} when type in [:f, :sp, :pc] ->
          [IO.ANSI.green(), value, IO.ANSI.white()]

        {type, value} when type in [:pc1, :pc2, :pc3] ->
          [IO.ANSI.magenta(), value, IO.ANSI.white()]

        {type, value} when type in [:pc0] ->
          instruction = Enum.at(@opcodetable, String.to_integer(value, 16))

          if special == :special,
            do: [IO.ANSI.light_magenta(), "#{value}[#{instruction}]", IO.ANSI.white()],
            else: [IO.ANSI.magenta(), value, IO.ANSI.white()]
      end)

    "#{IO.ANSI.white()}A: #{a} #{IO.ANSI.white()}F: #{f} #{IO.ANSI.white()}B: #{b} #{IO.ANSI.white()}C: #{c} #{IO.ANSI.white()}D: #{d} #{IO.ANSI.white()}E: #{e} #{IO.ANSI.white()}H: #{h} #{IO.ANSI.white()}L: #{l} #{IO.ANSI.white()}SP: #{sp} #{IO.ANSI.white()}PC: #{pc} (#{pc0} #{pc1} #{pc2} #{pc3}) #{if special == :special, do: "[broken]"}"
  end

  def dc(line) when is_binary(line) do
    case String.split(String.trim(line), " ") do
      [
        "A:",
        a,
        "F:",
        f,
        "B:",
        b,
        "C:",
        c,
        "D:",
        d,
        "E:",
        e,
        "H:",
        h,
        "L:",
        l,
        "SP:",
        sp,
        "PC:",
        pc,
        "(" <> pc0,
        pc1,
        pc2,
        pc3
      ] ->
        pc3 = String.trim(pc3, ")")

        [
          {:a, a},
          {:f, f},
          {:b, b},
          {:c, c},
          {:d, d},
          {:e, e},
          {:h, h},
          {:l, l},
          {:sp, sp},
          {:pc, pc},
          {:pc0, pc0},
          {:pc1, pc1},
          {:pc2, pc2},
          {:pc3, pc3}
        ]

      _ ->
        [
          {:a, "00"},
          {:f, "00"},
          {:b, "00"},
          {:c, "00"},
          {:d, "00"},
          {:e, "00"},
          {:h, "00"},
          {:l, "00"},
          {:sp, "00"},
          {:pc, "00"},
          {:pc0, "00"},
          {:pc1, "00"},
          {:pc2, "00"},
          {:pc3, "00"}
        ]
    end
  end

  def dc(_) do
    [
      {:a, "00"},
      {:f, "00"},
      {:b, "00"},
      {:c, "00"},
      {:d, "00"},
      {:e, "00"},
      {:h, "00"},
      {:l, "00"},
      {:sp, "00"},
      {:pc, "00"},
      {:pc0, "00"},
      {:pc1, "00"},
      {:pc2, "00"},
      {:pc3, "00"}
    ]
  end

  def diff([same | restl], [same | restr], left, right) do
    diff(restl, restr, [same | left], [same | right])
  end

  def diff([diff_left | restl], [diff_right | restr], left, right) do
    diff(restl, restr, [{:diff, diff_left} | left], [{:diff, diff_right} | right])
  end

  def diff([], [], left, right), do: {Enum.reverse(left), Enum.reverse(right)}
end

# Compare.run("out.txt", "BootromLog.txt")
# Compare.run("out.txt", "Blargg3.txt")
# Compare.run("out.txt", "Blargg10.txt")
# Compare.run("out.txt", "Blargg4.txt")
# Compare.run("out.txt", "Blargg6.txt")
# Compare.run("out.txt", "Blargg7.txt")
Compare.run("out.txt", "Blargg9.txt")

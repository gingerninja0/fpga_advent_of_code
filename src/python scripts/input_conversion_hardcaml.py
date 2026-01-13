input_filename = 'input.txt'
output_filename = 'output_hardcaml.txt'

results = []

length = 0

with open(input_filename, 'r') as f:
    for line in f:
        line = line.strip()

        prefix = line[0]
        value = int(line[1:])

        if prefix == 'L':
            number = -value
        else:
            number = value

        hex_val = f"{(number & 0xFFFF):04X}"
        
        results.append(hex_val)
        length = length + 1


index = 1026 # First index of data input

with open(output_filename, 'w') as out:
    out.write("(* Input start *)\n")
    out.write(f"{{addr = 0x0400; data = 0x0000_{length:04X} }}; (* 0x0400: Length of input *)\n")
    out.write(f"{{addr = 0x0401; data = 0x0000_0000 }}; (* 0x0401: Data starts after this value *)\n")

    for hex_val in results:
        out.write(f"{{addr = 0x{index:04X}; data = 0x0000_{hex_val} }};\n")
        index = index + 1

    out.write("(* Input end *)\n")

print("DONE!")

data = """
L68
L30
R48
L5
R60
L55
L1
L99
R14
L82
"""

input_filename = 'input.txt'
output_filename = 'output_test.txt'

lines = data.strip().split('\n')
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


print("// Input start")
print(f"0000_{((length) & 0xFFFF):04X}           // 31: Length of input")
print(f"0000_0000           // 32: Data starts after this value") 

for hex_val in results:
    print(f"0000_{hex_val}")


print("// Input end")

with open(output_filename, 'w') as out:
    out.write("// Input start\n")
    out.write(f"0000_{length:04X}           // Length of input\n")
    out.write(f"0000_0000           // Data starts after this value\n") 

    for hex_val in results:
        out.write(f"0000_{hex_val}\n")

    out.write("// Input end\n")

print("DONE!")
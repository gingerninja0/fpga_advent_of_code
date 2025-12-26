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

lines = data.strip().split('\n')
results = []

for line in lines:
    line = line.strip()

    prefix = line[0]
    value = int(line[1:])

    if prefix == 'L':
        number = -value
    else:
        number = value

    hex_val = f"{(number & 0xFFFF):04X}"
    
    results.append(hex_val)

print("// Input start")

length = 0
for hex_val in results:
    print(f"0000{hex_val}")
    length = length + 1

print(f"00000000")
print(f"0000{(length & 0xFFFF):04X} // Length of input")

print("// Input end")
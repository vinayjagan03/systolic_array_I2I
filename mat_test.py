import numpy as np
import os

mat1 = np.random.randint(0, 2**30, (4, 4))
mat2 = np.random.randint(0, 2**30, (4, 4))

#print(mat1, mat2, np.dot(mat1, mat2))

f = open('output.bin', 'wb')
f.write(np.dot(np.array(mat1), np.array(mat2)).astype('<i4').tobytes())
f.close()

f = open('input.bin', 'wb')

mat1_sequences = []
for i,j in enumerate(mat1):
    sequence = []
    for k in range(i):
        sequence.append(0)
    for k in j:
        sequence.append(k)
    for k in range(4-i):
        sequence.append(0)
    mat1_sequences.append(sequence)

mat2_sequences = []
for i,j in enumerate(mat2):
    sequence = []
    for k in range(i):
        sequence.append(0)
    for k in np.array(mat2)[:, i]:
        sequence.append(k)
    for k in range(4-i):
        sequence.append(0)
    mat2_sequences.append(sequence)

for i in range(8):    
    f.write(np.array(mat1_sequences, dtype='>i4')[:, i][::-1].tobytes())  
    f.write(np.array(mat2_sequences, dtype='>i4')[:, i][::-1].tobytes())  
        
f.close()

os.system('make systolic_array.sim')
result = os.popen('diff output_actual.bin output.bin').read()
if result == '':
    print('Success!')
else:
    print('Failure!')

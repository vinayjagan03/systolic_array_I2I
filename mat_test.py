import numpy as np
import os

n = 4

mat1 = np.random.rand(n, n)
mat2 = np.random.rand(n, n)

f=open('output.txt', 'w')
f.write(str(np.dot(mat1, mat2)))
f.close()

#print(np.dot(np.array(mat1), np.array(mat2)).astype('<f4'))

f = open('output.bin', 'wb')
f.write(np.dot(np.array(mat1), np.array(mat2)).astype('<f4').tobytes())
f.close()

f = open('input.bin', 'wb')

mat1_sequences = []
for i,j in enumerate(mat1):
    sequence = []
    for k in range(i):
        sequence.append(0)
    for k in j:
        sequence.append(k)
    for k in range(n-i):
        sequence.append(0)
    mat1_sequences.append(sequence)

mat2_sequences = []
for i,j in enumerate(mat2):
    sequence = []
    for k in range(i):
        sequence.append(0)
    for k in np.array(mat2)[:, i]:
        sequence.append(k)
    for k in range(n-i):
        sequence.append(0)
    mat2_sequences.append(sequence)

for i in range(n*2):    
    f.write(np.array(mat1_sequences, dtype='>f4')[:, i][::-1].tobytes())  
    f.write(np.array(mat2_sequences, dtype='>f4')[:, i][::-1].tobytes())  
        
f.close()

os.system('make systolic_array.sim')

f1 = open('output.bin', 'rb')
f2 = open('output_actual.bin', 'rb')

for i in range(n*n):
    a = f1.read(4)
    b = f2.read(4)
    if a != b:
        print(np.frombuffer(a, dtype=np.float32), np.frombuffer(b, dtype=np.float32))
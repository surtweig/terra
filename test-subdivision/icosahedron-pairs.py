tris = ((2, 9, 11), (3, 11, 9), (3, 5, 1), (3, 1, 7), (2, 6, 0),
 (2, 0, 4), (1, 8, 10), (0, 10, 8), (9, 4, 5), (8, 5, 4), (11, 7, 6),
 (10, 6, 7), (3, 9, 5), (3, 7, 11), (2, 4, 9), (2, 11, 6), (0, 8, 4),
 (0, 6, 10), (1, 5, 8), (1, 10, 7))

vertexes = (
(0, -1, -2),
(0, -1, 2),
(0, 1, -2),
(0, 1, 2),
(-2, 0, -1),
(-2, 0, 1),
(2, 0, -1),
(2, 0, 1),
(-1, -2, 0),
(-1, 2, 0),
(1, -2, 0),
(1, 2, 0) )

triset = []
for tri in tris:
    triset.append(set(tri))

pairs = []

for i in range(len(triset)):
    for j in range(i):
        tri1 = triset[i]
        tri2 = triset[j]
        s = tri1 & tri2
        if len(s) == 2:
            pairs.append( (i, j) )
print(pairs)

'''
coord = 1
cpairs = []
for pair in pairs:
    s = list(triset[pair[0]] & triset[pair[1]])
    #print(s)
    if vertexes[s[0]][coord] == vertexes[s[1]][coord]:
        cpairs.append( (s[0], s[1]) )

print(cpairs)
    
# [9, 11], [1, 3], [0, 2], [8, 10], [4, 5], [6, 7]
'''

'''
table = [ [ False for i in range(20) ] for j in range(20) ]

for pair in pairs:
    table[ pair[0] ][ pair[1] ] = True
    table[ pair[1] ][ pair[0] ] = True

for row in table:
    s = ""
    for item in row:
        s += 'X' if item else '.'
        s += ' '
    print(s)
'''

import copy

def collectpairs(cpairs, count):
    if count == 2:
        for p1 in cpairs:
            for p2 in cpairs:
                if p1[0] != p2[0] and p1[1] != p2[1] and p1[0] != p2[1] and p1[1] != p2[0]:
                    return [p1, p2]
    else:
        ppairs = collectpairs(cpairs, count-1)
        usedtris = set()
        for p in ppairs:
            usedtris.add(p[0])
            usedtris.add(p[1])
        for p in cpairs:
            if p not in ppairs:
                if p[0] not in usedtris and p[1] not in usedtris:
                    ppairs.append(p)
                    return ppairs

def collectpairs2(cpairs, usedtris, col, count, stack = ""):
    #print(stack, usedtris)
    for pair in cpairs:
        if pair[0] not in usedtris and pair[1] not in usedtris:
            col.append(pair)
            #print(stack, col)
            print(len(col))
            if len(col) == count:
                return col
            usedtris.add(pair[0])
            usedtris.add(pair[1])
            usedtris2 = copy.deepcopy(usedtris)
            col2 = copy.deepcopy(col)
            res = collectpairs2(cpairs, usedtris2, col2, count, stack+'   ')
            if res is not None:
                return res

            #usedtris.remove(pair[0])
            #usedtris.remove(pair[1])
            #col.remove(pair)

col = collectpairs2(pairs, set(), [], 10)
print(col)
                        
        





    

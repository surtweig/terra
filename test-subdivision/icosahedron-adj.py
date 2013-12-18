tris = ((2, 9, 11), (3, 11, 9), (3, 5, 1), (3, 1, 7), (2, 6, 0),
        (2, 0, 4), (1, 8, 10), (0, 10, 8), (9, 4, 5), (8, 5, 4), (11, 7, 6),
        (10, 6, 7), (3, 9, 5), (3, 7, 11), (2, 4, 9), (2, 11, 6), (0, 8, 4),
        (0, 6, 10), (1, 5, 8), (1, 10, 7))

adj = [ set() for _ in range(12) ]

for vertex in range(12):
    for tri in tris:
        if vertex in tri:
            for neighbour in tri:
                if neighbour != vertex:
                    adj[vertex].add(neighbour)

print(adj)

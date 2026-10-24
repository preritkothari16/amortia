PALETTE = [
    ("outline", "060504"), ("cloth_0", "0f0c0d"), ("cloth_1", "1b1617"), ("cloth_2", "2a2224"), ("cloth_3", "3a3033"),
    ("cold_0", "1f2128"), ("cold_1", "2f333b"),
    ("metal_0", "4c443f"), ("metal_1", "645a54"), ("metal_2", "7e726a"), ("metal_3", "988a80"),
    ("coat_0", "a39489"), ("coat_1", "bdb0a3"), ("coat_2", "d6ccbf"),
    ("skin_0", "4a3530"), ("skin_1", "6b493e"), ("skin_2", "8f6a5a"), ("skin_3", "b38f7c"), ("skin_4", "cfb1a0"),
    ("rust_0", "33211c"), ("rust_1", "593027"), ("rust_2", "7a4232"),
    ("blood_0", "340507"), ("blood_1", "5c0e0e"), ("blood_2", "7f1714"), ("blood_3", "9a2e25"), ("blood_4", "b8402f"),
    ("glow_0", "c94a1e"), ("glow_1", "ef7a2e"), ("glow_2", "ffb45a"), ("glow_3", "ffe0a0"),
    ("hair_hi", "2e2a33"),
]
def rgb(h): return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

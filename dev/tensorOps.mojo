from Tensor import Tensor
from runtime.llcl import Runtime
from algorithm import vectorize, parallelize

alias nelts = simdwidthof[DType.float32]()

@always_inline
fn mul(inout C: Tensor, A: Tensor, B: Tensor, rt: Runtime):
    let num_dims = A.getNum_dims()
    var A_matrix_size = A.shape[num_dims-2] * A.shape[num_dims-1]
    var B_matrix_size = B.shape[num_dims-2] * B.shape[num_dims-1]
    var C_matrix_size = C.shape[num_dims-2] * C.shape[num_dims-1]
    if(num_dims >= 3):
        A_matrix_size = A.skips[num_dims-3]
        B_matrix_size = B.skips[num_dims-3]
        C_matrix_size = C.skips[num_dims-3]

    let M = C.shape[num_dims-2]
    let K = A.shape[num_dims-1]
    let N = C.shape[num_dims-1] 

    for s in range(C.getCap() // C_matrix_size):
        let offset_A = s * A_matrix_size
        let offset_B = s * B_matrix_size
        let offset_C = s * C_matrix_size

        @parameter
        fn calc_row(m: Int):
            for k in range(K):
                @parameter
                fn dot[nelts: Int](n: Int):
                    C.data.simd_store[nelts](offset_C + m*N+n, C.data.simd_load[nelts](offset_C + m*N+n) + A.data.load(offset_A + m*K+k) * B.data.simd_load[nelts](offset_B + k*N+n))
                vectorize[nelts, dot](N)
        parallelize[calc_row](rt, M)

fn add(inout C: Tensor, A: Tensor, B: Tensor):
    let num_dims = A.getNum_dims()
    var matrix_size = A.getShape(num_dims-2) * A.getShape(num_dims-1)
    if(num_dims >= 3):
        matrix_size = A.getSkips(num_dims-3)

    let M = A.getShape(num_dims-2)
    let N = A.getShape(num_dims-1)

    if(C.getCap() > nelts):
        for i in range(0,C.getCap() - (nelts), nelts):
            print(i)
            C.data.simd_store[nelts](i, A.data.simd_load[nelts](i) + B.data.simd_load[nelts](i))
        for i in range(C.getCap() - nelts, C.getCap()):
            C.data.store(i, A.data.load(i) + B.data.load(i))
    else:
        for i in range(C.getCap()):
            C.data.store(i, A.data.load(i) + B.data.load(i))


fn ReLU(inout B: Tensor, A: Tensor):
    for i in range(A.getCap()):
        let val = A.getData(i)
        if(val < 0):
            B.setData(i,0)
        else:
            B.setData(i,val)

fn MSE(inout C: Tensor, A: Tensor, B: Tensor):
    for index in range(A.getCap()):
        let error = (A.getData(index) - B.getData(index)) * (A.getData(index) - B.getData(index))
        C.setData(0, C.getData(0) + error)
    C.setData(0, C.getData(0) / A.getCap())

fn reshape(inout B: Tensor, A: Tensor):
    return
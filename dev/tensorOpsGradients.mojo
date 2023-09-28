from Tensor import Tensor
from runtime.llcl import Runtime
from algorithm import parallelize, vectorize

alias nelts = simdwidthof[DType.float32]()

@always_inline
fn mul_grad(C: Tensor, inout A: Tensor, inout B: Tensor, rt: Runtime):

    let num_dims = A.getNum_dims()
    let A_matrix_size = A.shape[num_dims-2] * A.shape[num_dims-1]
    let B_matrix_size = B.shape[num_dims-2] * B.shape[num_dims-1]
    let C_matrix_size = C.shape[num_dims-2] * C.shape[num_dims-1] 

    let M = A.shape[num_dims-2]
    let K = B.shape[num_dims-2]  
    let N = B.shape[num_dims-1]

    for s in range(A.getCap() // A_matrix_size):
        let offset_C = s * C_matrix_size
        let offset_B = s * B_matrix_size
        let offset_A = s * A_matrix_size 

        if (A.getRequiresGradient()):

            for m in range(M):
                for k in range(K):
                    for n in range(N):
                        let index_A = offset_A + m * K + k
                        let index_C = offset_C + m * N + n
                        let index_B = offset_B + k * N + n
                        let a = A.getGradient(index_A) + C.getGradient(index_C) * B.getData(index_B) 
                        A.setGradient(index_A, a) 
            
            # @parameter
            # fn calc_row_1(m: Int):
            #     for k in range(K):
            #         @parameter
            #         fn dot[nelts: Int](n: Int):
            #             let index_A = offset_A + m * K + k
            #             let index_C = offset_C + m * N + n
            #             let index_B = offset_B + k * N + n
            #             let a = A.getGradient(index_A) + C.getGradient(index_C) * B.getData(index_B) 
            #             A.setGradient(index_A, a) 
            #         vectorize[nelts, dot](N)
            # parallelize[calc_row_1](rt, M)

        if (B.getRequiresGradient()): 
            for k in range(K):
                for n in range(N): 
                    for m in range(M): 
                        let index_B = offset_B + k * N + n
                        let index_A = offset_A + m * K + k
                        let index_C = offset_C + m * N + n
                        let b = B.getGradient(index_B) + A.getData(index_A) * C.getGradient(index_C)  
                        B.setGradient(index_B, b) 

            # @parameter
            # fn calc_row_2(k: Int):
            #     for n in range(N):
            #         @parameter
            #         fn dot[nelts: Int](m: Int):
            #             let index_B = offset_B + k * N + n
            #             let index_A = offset_A + m * K + k
            #             let index_C = offset_C + m * N + n
            #             let b = B.getGradient(index_B) + A.getData(index_A) * C.getGradient(index_C)  
            #             B.setGradient(index_B, b) 
            #         vectorize[nelts, dot](M)
            # parallelize[calc_row_2](rt, K)
            
fn add_grad(C: Tensor, inout A: Tensor, inout B: Tensor):
    A.setGradient(C.getGradient())
    B.setGradient(C.getGradient())

fn sum_grad(B: Tensor, inout A: Tensor):
    A.setGradientAll(1)

fn ReLU_grad(B: Tensor, inout A: Tensor):
    A.setGradient(B.getGradient())
    for i in range(A.getCap()):
        let val = A.getData(i)
        if val < 0:
            A.setGradient(i, 0)

fn MSE_grad(C: Tensor, inout A: Tensor, inout B: Tensor): # A: TrueVals, B: Logits
    let num_dims = A.getNum_dims()
    let M = A.getShape(num_dims-2)
    let N = A.getShape(num_dims-1)
    var matrix_size = M*N
    if(num_dims >= 3):
        matrix_size = A.getSkips(num_dims-3)

    for index in range(A.getCap()):
        let grad = Float32(2) * (B.getData(index) - A.getData(index)) / A.getCap()
        A.setGradient(index, grad) 
        B.setGradient(index, grad) 

fn reshape_grad(B: Tensor, inout A: Tensor):
    A.setGradient(B.getGradient())
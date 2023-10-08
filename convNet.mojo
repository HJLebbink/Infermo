from dv import *

# ###### This convNet (conv2d + maxPool2d) implementation has just started, nothing to see here so far! ###########################################################

# define the model and its behaviour
struct model:
    var nn: Module
    var input: Tensor
    var trueVals: Tensor
    var logits: Tensor
    var loss: Tensor
    var avgAcc: Float32

    fn __init__(inout self):
        self.input = Tensor(shape(64,784))
        self.input.requiresGradient = False
        self.trueVals = Tensor(shape(64,10))
        self.trueVals.requiresGradient = False
        self.nn = Module()
        self.avgAcc = 0

        # define model architecture
        var x = self.nn.reshape(self.input,shape(64,1,28,28))                                                   # 64,1,28,28
        x = Conv2d(self.nn,x,out_channels=4,kernel_width=4,kernel_height=4,stride=1,padding=0,use_bias=True)    # 64,4,24,24
        x = self.nn.maxPool2d(x,kernel_width=6,kernel_height=6,stride=6,padding=0)                              # 64,4,4,4
        x = self.nn.reshape(x,shape(64,64))                                                                     # 64,64
        x = Linear(self.nn,x,16,True,'ReLU')                                                                    # 64,32
        x = Linear(self.nn,x,10,True,'none')
        self.logits = self.nn.softmax(x)
        self.loss = self.nn.CE(self.trueVals,self.logits)

    @always_inline     
    fn forward(inout self, _input: DTypePointer[DType.float32], _trueVals: DTypePointer[DType.float32]) -> Tensor:

        # fill the input and trueVals Tensors with theri data
        self.nn.Tensors[0].setData(_input) # this is a bug, why cant we assign to self.input directly ? -> the id changes to two, dont know why
        self.trueVals.setData(_trueVals)

        # one forward pass through the network
        self.nn.forward(self.logits)

        # some additional ops, not necessary for the training, just for showing the accuracy
        let oneHots = max(self.logits)
        self.avgAcc = accuracy(oneHots,self.trueVals)

        return self.logits

    @always_inline
    fn backward(inout self):
        self.nn.backward(self.loss)

    @always_inline
    fn step(inout self):
        self.nn.optimize('sgd_momentum', lr = 0.1, momentum = 0.9, weight_decay=0.001)


# train the model
fn main()raises:

    # init
    var dl = DataLoader('./dv/datasets/mnist.txt')
    var model = model()

    let num_epochs = 10000
    var lossSum: Float32 = 0
    var avgAcc: Float32 = 0
    let every = 100

    for epoch in range(1,num_epochs+1):
        # load a batch of images into the model
        let inputs = dl.load(
            batchSize=64,
            start=1, # regarding the columns of the dataset
            end=785,
            scalingFactor=Float32(1)/Float32(255)
        )
        # load the labels for the images (oneHot encded from 0 to 9)
        let labels = dl.oneHot(
            batchSize=64,
            index=0,
            ndims=10
        )
        let logits = model.forward(inputs,labels)
        model.backward()
        model.step()

        lossSum += model.loss.getData(0)
        avgAcc += model.avgAcc
        if( epoch % every == 0):
            print("Epoch", epoch,", AvgLoss =", lossSum / every, ", AvgAccuracy =", avgAcc / every)
            lossSum = 0      
            avgAcc = 0
            # logits.printData()
            # model.trueVals.printData()


# fn main():
#     var nn = Module()

#     var A = Tensor(shape(1,1,6,6))
#     A.initRandn(1.0)

#     var B = nn.maxPool2d(
#             A=A,
#             kernel_width=3,
#             kernel_height=3,
#             stride=1,
#             padding=2
#         )

#     var C = nn.sum(B)

#     nn.forward(C)
#     nn.backward(C)

#     nn.printTensors()





# fn main():
# 	var nn = Module()

# 	var A = Tensor(shape(1,2,4,4))
# 	A.setDataAll(0.1)
	
	# var B = Conv2d(
	# 		nn=nn,
	# 		x=A,
	# 		out_channels=2,
	# 		kernel_width=3,
	# 		kernel_height=3,
	# 		stride=1,
	# 		padding=0,
	# 		use_bias=True     
	# 	)
	
	# var C = nn.sum(B)

	# nn.forward(C)
	# nn.backward(C)

	# nn.printTensors()

require 'sys'

require 'nn'
require 'mklnn'
--require 'cunn'

--require 'cudnn'
--cudnn.benchmark = true -- run manual auto-tuner provided by cudnn
--cudnn.verbose = false

-- require 'fbcunn'
-- require 'nnbhwd' -- not compiling anymore, file an issue
cmd = torch.CmdLine()
cmd:text()
cmd:text('Torch Convnet DailyTest')
cmd:text()
cmd:text('Options:')
cmd:option('-model', 'alexnet', 'default model')

params = cmd:parse(arg)

local nets = {}
if params.model == 'alexnet' then
nets[#nets+1] = require 'alexnet'
elseif params.model == 'overfeat' then
nets[#nets+1] = require 'overfeat'
elseif params.model == 'vgg_a' then
nets[#nets+1] = require 'vgg_a'
elseif params.model == 'googlenet' then
nets[#nets+1] = require 'googlenet'
end

local libs = {}
-- libs[#libs+1] = {cudnn.SpatialConvolution, cudnn.SpatialMaxPooling, cudnn.ReLU, 'BDHW', 'cudnn'}
-- libs[#libs+1] = {fbnn.SpatialConvolution, cudnn.SpatialMaxPooling, cudnn.ReLU, 'BDHW', 'fbnn'}
libs[#libs+1] = {nn.SpatialConvolution, nn.SpatialMaxPooling, nn.ReLU, 'BDHW', 'nn'}
--libs[#libs+1] = {nn.SpatialConvolutionMKLDNN, nn.SpatialMaxPoolingMKLDNN, nn.ReLUMKLDNN, 'BDHW', 'nn'}
-- libs[#libs+1] = {nn.SpatialConvolutionBHWD, nn.SpatialMaxPoolingBHWD, nn.ReLU, 'BHWD', 'nnBHWD'}

--print('Running on device: ' .. cutorch.getDeviceProperties(cutorch.getDevice()).name)
print('Running on CPU')
torch.setdefaulttensortype('torch.FloatTensor')

steps = 10 -- nb of steps in loop to average perf
nDryRuns = 10

function makeInput(config, size)
   local layout = config[4]
   local osize
   if layout == 'BDHW' then
      osize = size
   elseif layout == 'DHWB' then
      osize = {size[2],size[3],size[4],size[1]}
   elseif layout == 'BHWD' then
      osize = {size[1], size[3], size[4], size[2]}
   end
   return torch.randn(torch.LongStorage(osize))
end

for i=1,#nets do
   for j=1,#libs do
      collectgarbage()
      local model,model_name,size = nets[i](libs[j])
      model=mklnn.convert(model, 'mkl')
      print(model)
      local input = makeInput(libs[j],size) --:cuda()
      local lib_name = libs[j][5]
      print('ModelType: ' .. model_name, 'Kernels: ' .. lib_name,
            'Input shape: ' .. input:size(1) .. 'x' .. input:size(2) ..
               'x' .. input:size(3) .. 'x' .. input:size(4))

      -- dry-run
      for i=1,nDryRuns do
         model:zeroGradParameters()
         local output = model:updateOutput(input)
         local gradInput = model:updateGradInput(input, output)
         model:accGradParameters(input, output)
         --cutorch.synchronize()
         collectgarbage()
      end

      local tmf, tmbi, tmbg
      sys.tic()
      for t = 1,steps do
         output = model:updateOutput(input)
      end
      --cutorch.synchronize()
      tmf = sys.toc()/steps
      print(string.format("%-30s %25s %10.2f", lib_name, ':updateOutput():', tmf*1000))

      collectgarbage()
      sys.tic()
      for t = 1,steps do
         model:updateGradInput(input, output)
      end
      --cutorch.synchronize()
      tmbi = sys.toc()/steps
      print(string.format("%-30s %25s %10.2f", lib_name, ':updateGradInput():', tmbi*1000))

      collectgarbage()
      sys.tic()
      local ok = 1
      for t = 1,steps do
         ok = pcall(function() model:accGradParameters(input, output) end)
      end
      --cutorch.synchronize()
      tmbg = sys.toc()/steps
      if not ok then
         print(string.format("%-30s %25s %s", lib_name, ':accGradParameters():', 'FAILED!'))
      else
         print(string.format("%-30s %25s %10.2f", lib_name, ':accGradParameters():', tmbg*1000))
      end
      print(string.format("%-30s %25s %10.2f", lib_name, ':Forward:', (tmf)*1000))
      print(string.format("%-30s %25s %10.2f", lib_name, ':Backward:', (tmbi+tmbg)*1000))
      print(string.format("%-30s %25s %10.2f", lib_name, ':TOTAL:', (tmf+tmbi+tmbg)*1000))
      print()
   end
end

print('')

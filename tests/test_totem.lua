require 'totem'

local tablex = require 'pl.tablex'

local tester = totem.Tester()

local MESSAGE = "a really useful informative error message"

local subtester = totem.Tester()
-- The message only interests us in case of failure
subtester._success = function(self) return true, MESSAGE end
subtester._failure = function(self, message) return false, message end

local tests = totem.TestSuite()

local test_name_passed_to_setUp
local calls_to_setUp = 0
local calls_to_tearDown = 0

local function meta_assert_success(success, message)
  tester:assert(success==true, "assert wasn't successful")
  tester:assert(string.find(message, MESSAGE) ~= nil, "message doesn't match")
end
local function meta_assert_failure(success, message)
  tester:assert(success==false, "assert didn't fail")
  tester:assert(string.find(message, MESSAGE) ~= nil, "message doesn't match")
end

function tests.really_test_assert()
  assert((subtester:assert(true, MESSAGE)),
         "subtester:assert doesn't actually work!")
  assert(not (subtester:assert(false, MESSAGE)),
         "subtester:assert doesn't actually work!")
end

function tests.test_assert()
  meta_assert_success(subtester:assert(true, MESSAGE))
  meta_assert_failure(subtester:assert(false, MESSAGE))
end

function tests.test_assertTensorEq_alltypes()
  local allTypes = {
      torch.ByteTensor,
      torch.CharTensor,
      torch.ShortTensor,
      torch.IntTensor,
      torch.LongTensor,
      torch.FloatTensor,
      torch.DoubleTensor,
  }
  for _, tensor in ipairs(allTypes) do
    local t1 = tensor():ones(10)
    local t2 = tensor():ones(10)
    meta_assert_success(subtester:assertTensorEq(t1, t2, 1e-6, MESSAGE))
  end
end

function tests.test_assertTensorSizes()
  local t1 = torch.ones(2)
  local t2 = torch.ones(3)
  local t3 = torch.ones(1,2)
  meta_assert_failure(subtester:assertTensorEq(t1, t2, 1e-6, MESSAGE))
  meta_assert_failure(subtester:assertTensorNe(t1, t2, 1e-6, MESSAGE))
  meta_assert_failure(subtester:assertTensorEq(t1, t3, 1e-6, MESSAGE))
  meta_assert_failure(subtester:assertTensorNe(t1, t3, 1e-6, MESSAGE))
end

function tests.test_assertTensorEq()
  local t1 = torch.randn(100,100)
  local t2 = t1:clone()
  local t3 = torch.randn(100,100)
  meta_assert_success(subtester:assertTensorEq(t1, t2, 1e-6, MESSAGE))
  meta_assert_failure(subtester:assertTensorEq(t1, t3, 1e-6, MESSAGE))
end

function tests.test_assertTensorNe()
  local t1 = torch.randn(100,100)
  local t2 = t1:clone()
  local t3 = torch.randn(100,100)
  meta_assert_success(subtester:assertTensorNe(t1, t3, 1e-6, MESSAGE))
  meta_assert_failure(subtester:assertTensorNe(t1, t2, 1e-6, MESSAGE))
  end

function tests.test_assertTensor_epsilon()
  local t1 = torch.rand(100,100)
  local t2 = torch.rand(100,100)*1e-5
  local t3 = t1 + t2
  meta_assert_success(subtester:assertTensorEq(t1, t3, 1e-4, MESSAGE))
  meta_assert_failure(subtester:assertTensorEq(t1, t3, 1e-6, MESSAGE))
  meta_assert_success(subtester:assertTensorNe(t1, t3, 1e-6, MESSAGE))
  meta_assert_failure(subtester:assertTensorNe(t1, t3, 1e-4, MESSAGE))
end

function tests.test_assertTable()
  local tensor = torch.rand(100,100)
  local t1 = {1, "a", key = "value", tensor = tensor, subtable = {"nested"}}
  local t2 = {1, "a", key = "value", tensor = tensor, subtable = {"nested"}}
  meta_assert_success(subtester:assertTableEq(t1, t2, MESSAGE))
  meta_assert_failure(subtester:assertTableNe(t1, t2, MESSAGE))
  for k,v in pairs(t1) do
    local x = "something else"
    t2[k] = nil
    t2[x] = v
    meta_assert_success(subtester:assertTableNe(t1, t2, MESSAGE))
    meta_assert_failure(subtester:assertTableEq(t1, t2, MESSAGE))
    t2[x] = nil
    t2[k] = x
    meta_assert_success(subtester:assertTableNe(t1, t2, MESSAGE))
    meta_assert_failure(subtester:assertTableEq(t1, t2, MESSAGE))
    t2[k] = v
    meta_assert_success(subtester:assertTableEq(t1, t2, MESSAGE))
    meta_assert_failure(subtester:assertTableNe(t1, t2, MESSAGE))
  end
end

function tests.test_assertEqRet()
  -- Create subtester - only a 'ret' value of false should trigger assertions
  local function makeRetTester(ret)
    local retTester = totem.Tester()
    local retTests = totem.TestSuite()

    function retTests.testEq()
      retTester:eq({1}, {1}, '', 0, ret)
      retTester:eq({1}, {2}, '', 0, ret)
    end

    return retTester:add(retTests)
  end

  local retTesterNoAssert = makeRetTester(true)
  local retTesterAssert = makeRetTester(false)

  -- Change the write function so that the sub testers do not output anything
  local oldWrite = io.write
  io.write = function() end

  retTesterNoAssert:run()
  retTesterAssert:run()

  -- Restore write function
  io.write = oldWrite

  tester:asserteq(retTesterNoAssert.countasserts, 0,
                  "retTesterNoAssert should not have asserted")

  tester:asserteq(retTesterAssert.countasserts, 2,
                  "retTesterAssert should have asserted twice")
end

local function good_fn() end
local function bad_fn() error("muahaha!") end

function tests.test_assertError()
  meta_assert_success(subtester:assertError(bad_fn, MESSAGE))
  meta_assert_failure(subtester:assertError(good_fn, MESSAGE))
end

function tests.test_assertNoError()
  meta_assert_success(subtester:assertNoError(good_fn, MESSAGE))
  meta_assert_failure(subtester:assertNoError(bad_fn, MESSAGE))
end

function tests.test_assertErrorPattern()
  meta_assert_success(subtester:assertErrorPattern(bad_fn, "haha", MESSAGE))
  meta_assert_failure(subtester:assertErrorPattern(bad_fn, "hehe", MESSAGE))
end

function tests.test_TensorEqChecks()
  local t1 = torch.randn(100,100)
  local t2 = t1:clone()
  local t3 = torch.randn(100,100)

  local success, msg = totem.areTensorsEq(t1, t2, 1e-5)
  tester:assert(success, "areTensorsEq should return true")
  tester:asserteq(msg, nil, "areTensorsEq erroneously gives msg on success")

  local success, msg = totem.areTensorsEq(t1, t3, 1e-5)
  tester:assert(not success, "areTensorsEq should return false")
  tester:asserteq(type(msg), 'string', "areTensorsEq should return a message")

  tester:assertNoError(function() totem.assertTensorEq(t1, t2, 1e-5) end,
                       "assertTensorEq not raising an error")
  tester:assertError(function() totem.assertTensorEq(t1, t3, 1e-5) end,
                     "assertTensorEq not raising an error")
end

function tests.test_TensorNeChecks()
  local t1 = torch.randn(100,100)
  local t2 = t1:clone()
  local t3 = torch.randn(100,100)

  local success, msg = totem.areTensorsNe(t1, t3, 1e-5)
  tester:assert(success, "areTensorsNe should return true")
  tester:asserteq(msg, nil, "areTensorsNe erroneously gives msg on success")

  local success, msg = totem.areTensorsNe(t1, t2, 1e-5)
  tester:assert(not success, "areTensorsNe should return false")
  tester:asserteq(type(msg), 'string', "areTensorsNe should return a message")

  tester:assertNoError(function() totem.assertTensorNe(t1, t3, 1e-5) end,
                       "assertTensorNe not raising an error")
  tester:assertError(function() totem.assertTensorNe(t1, t2, 1e-5) end,
                     "assertTensorNe not raising an error")
end

function tests.test_TensorArgumentErrorMessages()
  local t = torch.ones(1)
  local funcs = {
      totem.areTensorsEq,
      totem.areTensorsNe,
      totem.assertTensorEq,
      totem.assertTensorNe,
  }

  for _, fn in ipairs(funcs) do
    tester:assertErrorPattern(function() fn(nil, t, 0) end, "First argument")
    tester:assertErrorPattern(function() fn(t, nil, 0) end, "Second argument")
    tester:assertErrorPattern(function() fn(t, t, "nan") end, "Third argument")
  end
end

function tests.testSuite_duplicateTests()
    function createDuplicateTests()
        local tests = totem.TestSuite()
        function tests.testThis()
        end
        function tests.testThis()
        end
    end
    tester:assertErrorPattern(createDuplicateTests,
                              "Test testThis is already defined.")
end

function tests.test_checkGradientsAcceptsGenericOutput()
    require 'nn'
    local Mod = torch.class('totem.dummyClass', 'nn.Module')
    function Mod:updateOutput(input)
        self.output = {
            [1] = {
                [1] = torch.randn(3, 5),
                [2] = 1,
                strKey = 3,
            },
            [2] = 1,
            [3] = torch.randn(3, 5),
            strKey = 4
        }
        return self.output
    end
    function Mod:updateGradInput(input, gradOutput)
        self.gradInput = input:clone():fill(0)
        return self.gradInput
    end
    local mod = totem.dummyClass()
    totem.nn.checkGradients(tester, mod, torch.randn(5, 5), 1e-6)
end


function tests.test_setUp()
    tester:asserteq(test_name_passed_to_setUp, 'test_setUp')
    for key, value in pairs(tester.tests) do
        tester:assertne(key, '_setUp')
    end
end


function tests.test_tearDown()
    for key, value in pairs(tester.tests) do
        tester:assertne(key, '_tearDown')
    end
end


function tests._setUp(name)
    test_name_passed_to_setUp = name
    calls_to_setUp = calls_to_setUp + 1
end


function tests._tearDown(name)
    calls_to_tearDown = calls_to_tearDown + 1
end


tester:add(tests):run()


-- Additional tests to check that _setUp and _tearDown were called.
local test_count = tablex.size(tester.tests)
local postTests = totem.TestSuite()
local postTester = totem.Tester()

function postTests.test_setUp(tester)
    postTester:asserteq(calls_to_setUp, test_count,
                        "Expected " .. test_count .. " calls to _setUp")
end

function postTests.test_tearDown()
    postTester:asserteq(calls_to_tearDown, test_count,
                       "Expected " .. test_count .. " calls to _tearDown")
end


postTester:add(postTests):run()

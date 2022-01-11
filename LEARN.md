# Freezing contracts with DOS attacks
Welcome back! In this quest, you will learn about the three most common types of Denial Of Service attacks in Solidity. There are three major mistakes every Solidity developer should be aware of:
1 - Progressing state depending on external calls.
2 - Allowing gas overconsumption.
3 - Allowing external callers to cause expensive looping.
So let’s dive into each one of these and see how can we prevent such attacks. There are more cases to discuss because each attack that renders your contract inoperable (even for a short period of time) is considered a DOS attack. But let’s have a look at the main ones here.  

You can try this quests on Remix. Make sure you are on Mumbai, and have fun!

## The first case:
If the state of a contract depends on other addresses (people or contracts) calling it, this can leave room for a DOS. Let’s consider the following scenario:
You wrote a contract called QuoteRecorder, it lets users record their favorite quotes on Polygon. But only one quote of one specific user can be kept in the contract’s state at a time. That is, if you pay more than the current quote owner, you get to record your own and the previous owner gets refunded. Let’s take a look:

```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract QuoteRecorder {
   address payable public currentQuoteLover;
   uint256 public balance;
   string public currentQuote;
 
   function record(string memory quote) external payable {
       require(msg.value > balance);
       (bool sent, ) = currentQuoteLover.call{value: balance}("");
       require(sent);
       balance = msg.value;
       currentQuoteLover = payable(msg.sender);
       currentQuote = quote;
   }
}
```

The logic is simple, all you have to do is to send more MATICs than there are already in the contract and enjoy your quote being recorded! You can see here that the contract is sending funds to the previous owner:

```js
(bool sent, ) = currentQuoteLover.call{value: balance}("");
require(sent);
```

The _call()_ function is a low-level function that can be used to send MATICs. But it does not revert if an error occurs, it just moves on. That is why there is a _require()_ statement. But anyway, you can use this function if you would like your function to continue on even if the _call()_ did not execute normally. But wait, this line is hackable! What if an Attack contract that does not have a _receive()_ or a _fallback()_ method calls the function record? This contract just cannot receive MATICS. What will happen is the _call()_ will not return a true on success, the boolean named “sent” will be false, and the state will freeze rendering our contract useless. Let’s see how this _Attack_ contract works: 

```js
contract Attack {
   function attack(QuoteRecorder _quoteRecorder) public payable {
       _quoteRecorder.record{value: msg.value}("Be careful of DOS hacks");
   }
}
```

Easy, right? This attack function will call function record with a proper _msg.value_ and since it has no MATICreceiving method, the hack will be complete. Feel free to try it, it is just fun to do!
So how to prevent such exploit? It is recommended to implement a withdrawal pattern. That is, store balances in a _mapping(address=>uint)_ and allow users to withdraw on their own calling a separate function. Remember, it is better to keep things on your side. That is, do not rely on external calls for your state to progress.

## The second case:
There is another way to hack _QuoteRecorder_. You can write a fallback function that consumes all gas specified for the transaction. Remember, each block has a gas limit, you can’t include as many computations as you would like in a smart contract. So let’s write an _Attack_ contract that hacks _QuoteRecorder_. It is the same as _Attack_ in the first subquest, except that you allow _Attack_ to receive MATICs. But at what cost! _Attack_’s fallback will be like this:

```js
fallback() external payable{
       assert(1 == 0);
   }
```

I mean, this just hurts my eyes. This will consume all gas when _QuoteRecorder_ tries to send MATICs to _Attack_. You can add any false statement inside _assert_, the unmerciful _assert_ will consume all gas. Notice that this hack will work even if _QuoteRecorder_ does not check for the success of _call()_. That is, even if the line _(require(sent);)_ Was not there. The code execution will not even reach it. There are many ways to abuse gas causing a transaction to fail, you can run an infinite loop or any extensive computation really.
So, How to prevent gas overconsumption? You can just specify the gas limit a transaction can use:

```js
(bool sent, ) = currentQuoteLover.call{value: balance, gas:5000}("");
```

Note that you just prevented gas abuse, but did not prevent the hack itself. To prevent the hack implement the withdrawal pattern. Create a function that allows users to withdraw their balances. This is also good for the single responsibility principle (do one thing, and do it well). This way, malicious users cannot stop the state from progressing. Ok cool, let’s take a look at the third case.

## The third case:
Suppose you created your own ERC20 token named Quote and you want to reward those who used your contracts. You would like to show appreciation by sending 10 tokens for each recorder (each user who recorded his/her quote). So you wrote the following:

```js
// SPDX-License-Identifier: MIT
 
pragma solidity ^0.8.0;
 
contract QuoteRecorder {
   address payable public currentQuoteLover;
   address public owner;
   uint256 public balance;
   string public currentQuote;
   address[] public recorders;
 
   constructor() {
       owner = msg.sender;
   }
 
   function record(string memory quote) external payable {
       require(msg.value > balance);
       currentQuoteLover.transfer(balance);
       balance = msg.value;
       currentQuoteLover = payable(msg.sender);
       currentQuote = quote;
       recorders.push(msg.sender);
   }
 
   function reward() public view {
       require(msg.sender == owner);
       for (uint256 i = 0; i < recorders.length; i++) {
           //supposing that distributeToken is implemented
           distributeToken(recorders[i], 10);
       }
   }
}
```

Notice the new line in the _record_ function, every new recorder gets pushed. Take a look at the new function _reward_, it loops through the recorders array and transfers 10 tokens for each user. We are supposing that you coded an ERC20 token and implemented a _distributeToken_ function. So what is the problem! Only the owner can initiate this loop. Well yes, but a malicious user can create many accounts and push many addresses to recorders forcing _reward()_ to exceed the gas limit when executing. Smart contracts should not loop over data structures that can be manipulated by external calls. Again, use a withdrawal pattern, create a _withdraw()_ function that allows recorders to withdraw those 10 tokens. Alright, you did it! Let’s finish up with some remarks.

## Final remarks:
We have seen how common DOS attacks can happen, there are plenty of ways to “freeze” a contract. Be sure to give users minimum privileges, and think about possible ways a malicious contract can hack you. Read functions specifications before using them. Like the previously-mentioned _call()_ function, it can cause lots of problems if not used properly. Remember to always implement a withdrawal pattern and separate responsibilities between functions. The end! Good luck with your journey in the amazing world of smart contracts, Happy coding!

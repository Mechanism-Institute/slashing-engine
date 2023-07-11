# Gitcoin Slashing Engine

Built with love, using [foundry](https://book.getfoundry.sh/).

## Philosophy

Smart contracts merge [economic action and speech](https://www.kernel.community/en/learn/module-2/money-speech). This allows anyone to **verify transparently** the value associated with any speech act.

This does not mean verified speech is "true" in some objective sense, nor does it make it automatically trustworthy, becase [trust requires reliable, relatable social foundations](kernel.community/en/learn/module-0/trust/) (_truwe_) as much as it requires verification (_veritas_).

What smart contracts do offer is **quantifiable legitimacy** based on the cost to speak, or the value at risk for choosing to speak a particular way.

On the surface, this may appear plutocratic: only those who already have value get to speak. However, when it comes to virtual currencies, scarcity is a design choice, not an innate feature of the environment. Who has the tokens required to speak in any particular way is primarily a function of how we create our economies*.

Now, because verified speech =/= objectively true speech, the whole community has struggled to apply the outputs of inherently subjective computation within the new domain of smart contracts. First, we needed to fetch price information from "off-chain". The solution to this was a network of "[price oracles](https://github.com/chronicleprotocol/omnia-feed)", all of whom put some value at risk, and were duly rewarded for providing results that agreed with the other oracles and could be realistically cross-checked (note: not providing "true" results, just results that don't diverge from consensus). 

Then, we needed to fetch more complex and subjective data, like the "health" of an ecosystem. This has led to various approaches to "MRV" and trying to encapsulate it in an effective, impactful, and "fair" way on-chain, again using something like a system of oracles who "agree", rather than trying to stipulate exactly what the "truth" is. How impactful this will be remains to be seen.

For even more subjective data - like the outcome of some predicition, or the resolution of some conflict - we have developed tools like reality.eth and Kleros. While interesting, [reality.eth taxes our collective attention and requires extremely careful setup](https://www.youtube.com/watch?v=MjnmauH4GKI) and Kleros has had mixed results at best. This is because once we introduce subjective data, even if we verify it on-chain, all we have verified is our own perspective and the age-old question remains: ["Who will guard the guards?"](https://www.nobelprize.org/uploads/2018/06/hurwicz_lecture.pdf).

This contract suggests one possible solution: (i) have the guards guard themselves by placing meaningful value at risk and (ii) create a meaningfully feedback loop between the general population (i.e. the DAO) and the guards such that the threshold required for any decision taken by the guards to be enacted may be regularly calibrated based on their performance.

## Problem Statement

Gitcoin has become adept at identifying sybil accounts. They wish to apply this skill to identifying and punishing sybil accounts misusing Gitcoin passports to pose as unique humans. While some techniques for identifying such accounts approach the objective, it is logically impossible for any method to fully prove a negative: i.e. even if we open source the exact methods by which sybils are identified, it is not possible to claim with 100% certainty that `0xdeadbeef` is **not** a unique human.

There are numerous additional hurdles to overcome:

1. We cannot open source the exact methodology in full any way, as that will lead to new techniques for generating sybils which pass the checks in a constantly escalating game.
2. If we put more data on-chain, how do we preserve privacy? ZKPs are one legitimate approach here.
3. If we do use ZKPs to put data on chain, how do we:
    1. make sure that the checks do not leak information
    2. make sure that the way the checks happen do not reveal exactly how we flag sybils, leading us back to problem 1.
4. There are also questions of implementation complexity tangled up with all the above: both in terms of ZKPs and in terms of running various sybil checks on chain in a gas efficient way.

Rather than tackling the above head-on, is there a way we can route around some of the challenges outlined above? We want Passport to become a powerful tool for ensuring that unique humans are using any given application, and in order to ensure that occurs, we need to balance economic rewards and punishments well. How can we achieve such a blance in the simplest way possible? 

## How It Works

1. Anyone can stake any amount of GTC.
2. If that amount exceeds some "floor", set (and updated) by the DAO, they are a "guardian".
3. There is no limit on the number of guardians - the DAO can tweak the floor at will to raise or lower the amount according to their own judgment.
4. Gurdians can flag any account as a sybil. 
5. The amount that the guardian has staked is stored as the `amountCommitted` to the claim that the account flagged is a sybil account.
6. The `amountCommitted` to an account flagged as a sybil must exceed a specific threshold before it can be unstaked in the passport contract.
7. This threshold is set by the DAO. In particular, we take the highest amount staked by any guardian and multiply it by the `CONFIDENCE` factor the DAO sets. We do this to ensure that it always requires more than one guardian - no matter how much they stake - to cause any account flagged as a sybil to be slashed.
8. Guardians can also vote to slash other guardians if they are behaving maliciously (i.e. flagging accounts as sybils who are not). If the number of guardians voting on one guardian to be slashed exceeds some threshold - also set by the DAO - that guardian is slashed.

## Motivation

We believe this presents an interesting solution to various different governance games which rely on subjective data submitted by different parties, whose opinions will both overlap and diverge. 

It ensures that where there is significant agreement, action can be taken immediately and transparently, while also making sure that the extent of overlap required can be updated and recalibrated based on feedback from the broad base of people effected by the decisions of any smaller group willing to put value at stake in order to make decisions.

This kind of pattern may have broader application. For instance, how are the alliance of PGN members to decide upon what to do with the fees generated by running their own Layer 2? This mechanism is one way in which to approach such a question.

## Open Questions

What do we do with GTC that is (i) unstaked from the passport contract or (ii) slashed if a guardian is voted out?

In general, we expect the [number of unstaking events to be vanishingly small](https://beaconcha.in/validators/slashings). Generally speaking, it is enough that the mechanism exists in a verified and executive state (i.e. it can take action) to prevent most behaviours which would be at odds with the stated aims of the protocol. The same thinking applies to slashing guardians.

That said, we still need to decide whether to burn the GTC or return it to the guardians who correctly identified sybils. The first is easy and simple. The second creates the kind of incentives which may be required to encourage a meaningful number of guardians to participate, but it also (i) potentially creates incentives for falsely flagging accounts (especially those who stake high amounts of GTC on their passport: precisely the opposite of what we want to achieve), (ii) adds to the implementation complexity and (iii) could be cause for regulatory concerns unless we are able to allocate exact amounts to specific guardians based on identifiable actions they have taken. 

I therefore recommend the burn approach, but this remains up for debate.

### Footnotes

It is critically important we do not repeat or amplify economic injustice. However, the way to do this is not through some "equitable" distribution scheme: it is by [designing economies with win-win transactions](https://github.com/norvig/pytudes/blob/main/ipynb/Economics.ipynb). It is _the nature of transactions_ which counts most. In the current paradigm, when I win (i.e. if my option is "in the money") it is only because someone else has lost. If these kind of win-loss transactions are the only possibility, then wealth inequality can only increase. 

There are some examples of protocols that enable win-win transactions emerging: [Maker](https://www.kernel.community/en/tokens/token-studies/maker-difference) and [Rocket Pool](https://www.kernel.community/en/tokens/token-studies/rocket-pool) being some of the leading ones. Even Ethereum 2.0 staking is itself a good example. While 32 ETH may seem exclusionary and plutocratic, (i) there are [good reasons for choosing this value as an acceptable trade-off between economic inclusion and the overhead in messages](https://notes.ethereum.org/@vbuterin/serenity_design_rationale?type=view#Why-32-ETH-validator-sizes) and (ii) it has prompted the creation of various creative schemes - like Rocket Pool - to ensure that everyone who has even a small amount of ETH can participate meaningfully and benefit from their choice.
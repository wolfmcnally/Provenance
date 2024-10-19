import Foundation
import DCBOR
import WolfBase
import BCRandom

public struct ProvenanceMarkGenerator: Codable, Hashable {
    public let _res: Int
    public let seed: Data
    public let chainID: Data
    public var nextSeq: UInt32
    public var rngState: Data
    
    // KLUDGE ALERT: Temporary workaround for the fact that pre-release SwiftData
    // does not properly persist codable enums!
    public var res: ProvenanceMarkResolution {
        ProvenanceMarkResolution(rawValue: _res)!
    }

    public init(resolution res: ProvenanceMarkResolution, seed: Data, chainID: Data, nextSeq: UInt32, rngState: Data) {
        self._res = res.rawValue
        self.seed = seed
        self.chainID = chainID
        self.nextSeq = nextSeq
        self.rngState = rngState
    }
    
    public init(resolution res: ProvenanceMarkResolution, seed: Data) {
        let chainID = seed.prefix(res.linkLength)
        self.init(resolution: res, seed: seed, chainID: chainID, nextSeq: 0, rngState: seed)
    }

    public init<R>(resolution res: ProvenanceMarkResolution, using rng: inout R) where R: RandomNumberGenerator {
        // Randomness for a new seed can come from any secure random number generator.
        let seed = rng.randomData(32)
        self.init(resolution: res, seed: seed)
    }
    
    public init(resolution res: ProvenanceMarkResolution) {
        var rng: RandomNumberGenerator = SecureRandomNumberGenerator.shared
        self.init(resolution: res, using: &rng)
    }
    
    public init(resolution res: ProvenanceMarkResolution, passphrase: String) {
        let seed = extendKey(passphrase.utf8Data)
        self.init(resolution: res, seed: seed)
    }
    
    public mutating func next(date: Date = Date(), info: (any CBOREncodable)? = nil) -> ProvenanceMark {
        defer {
            nextSeq += 1
        }
        
        var rng = Xoshiro256StarStar(rngState)
        
        let key: Data
        if nextSeq == 0 {
            key = chainID
        } else {
            // The randomness generated by the PRNG should be portable across implementations.
            key = rng.nextBytes(res.linkLength)
            rngState = rng.stateData
        }
        
        var nextRNG = rng
        let nextKey = nextRNG.nextBytes(res.linkLength)
        
        return ProvenanceMark(resolution: res, key: key, nextKey: nextKey, chainID: chainID, seq: nextSeq, date: date, info: info)!
    }
}

extension ProvenanceMarkGenerator: CustomStringConvertible {
    public var description: String {
        "ProvenanceMarkGenerator(chainID: \(chainID.hex), res: \(res), seed: \(seed.hex), nextSeq: \(nextSeq), rngState: \(rngState.hex))"
    }
}

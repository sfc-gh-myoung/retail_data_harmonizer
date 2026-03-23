import { describe, it, expect } from 'vitest'
import {
  algorithmsResponseSchema,
  agreementResponseSchema,
  sourcePerformanceResponseSchema,
  methodAccuracyResponseSchema,
} from './schemas'

describe('algorithmsResponseSchema', () => {
  const validAlgorithmsData = {
    algorithms: [
      {
        name: 'Search',
        description: 'Full-text search matching',
        features: ['Fast', 'Good for exact matches', 'Handles typos'],
      },
      {
        name: 'Cosine',
        description: 'Vector similarity using TF-IDF',
        features: ['Semantic matching', 'Language agnostic'],
      },
    ],
  }

  it('parses valid algorithms response', () => {
    const result = algorithmsResponseSchema.safeParse(validAlgorithmsData)
    expect(result.success).toBe(true)
  })

  it('returns correct algorithm structure', () => {
    const result = algorithmsResponseSchema.parse(validAlgorithmsData)
    expect(result.algorithms).toHaveLength(2)
    expect(result.algorithms[0].name).toBe('Search')
    expect(result.algorithms[0].features).toHaveLength(3)
  })

  it('accepts empty algorithms array', () => {
    const result = algorithmsResponseSchema.safeParse({ algorithms: [] })
    expect(result.success).toBe(true)
    if (result.success) {
      expect(result.data.algorithms).toHaveLength(0)
    }
  })

  it('rejects missing algorithms field', () => {
    const result = algorithmsResponseSchema.safeParse({})
    expect(result.success).toBe(false)
  })

  it('rejects invalid algorithm structure', () => {
    const invalid = {
      algorithms: [{ name: 'Search' }], // missing description and features
    }
    const result = algorithmsResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })

  it('rejects non-string features', () => {
    const invalid = {
      algorithms: [{
        name: 'Search',
        description: 'Test',
        features: [123, 456], // should be strings
      }],
    }
    const result = algorithmsResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})

describe('agreementResponseSchema', () => {
  const validAgreementData = {
    agreement: [
      { level: 'High (5/5)', count: 150, avgConfidence: 0.95 },
      { level: 'Medium (4/5)', count: 200, avgConfidence: 0.85 },
      { level: 'Low (3/5)', count: 100, avgConfidence: 0.70 },
    ],
  }

  it('parses valid agreement response', () => {
    const result = agreementResponseSchema.safeParse(validAgreementData)
    expect(result.success).toBe(true)
  })

  it('returns correct agreement structure', () => {
    const result = agreementResponseSchema.parse(validAgreementData)
    expect(result.agreement).toHaveLength(3)
    expect(result.agreement[0].level).toBe('High (5/5)')
    expect(result.agreement[0].avgConfidence).toBe(0.95)
  })

  it('accepts empty agreement array', () => {
    const result = agreementResponseSchema.safeParse({ agreement: [] })
    expect(result.success).toBe(true)
    if (result.success) {
      expect(result.data.agreement).toHaveLength(0)
    }
  })

  it('rejects missing agreement field', () => {
    const result = agreementResponseSchema.safeParse({})
    expect(result.success).toBe(false)
  })

  it('rejects invalid agreement item structure', () => {
    const invalid = {
      agreement: [{ level: 'High' }], // missing count and avgConfidence
    }
    const result = agreementResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })

  it('rejects non-number avgConfidence', () => {
    const invalid = {
      agreement: [{ level: 'High', count: 100, avgConfidence: 'high' }],
    }
    const result = agreementResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})

describe('sourcePerformanceResponseSchema', () => {
  const validSourcePerformanceData = {
    sourcePerformance: [
      {
        source: 'POS_A',
        itemCount: 500,
        avgSearch: 0.85,
        avgCosine: 0.80,
        avgEdit: 0.75,
        avgJaccard: 0.70,
        avgLlm: 0.90,
        avgEnsemble: 0.88,
      },
      {
        source: 'POS_B',
        itemCount: 300,
        avgSearch: 0.82,
        avgCosine: 0.78,
        avgEdit: 0.72,
        avgJaccard: 0.68,
        avgLlm: 0.88,
        avgEnsemble: 0.85,
      },
    ],
  }

  it('parses valid source performance response', () => {
    const result = sourcePerformanceResponseSchema.safeParse(validSourcePerformanceData)
    expect(result.success).toBe(true)
  })

  it('returns correct source performance structure', () => {
    const result = sourcePerformanceResponseSchema.parse(validSourcePerformanceData)
    expect(result.sourcePerformance).toHaveLength(2)
    expect(result.sourcePerformance[0].source).toBe('POS_A')
    expect(result.sourcePerformance[0].avgEnsemble).toBe(0.88)
  })

  it('accepts empty sourcePerformance array', () => {
    const result = sourcePerformanceResponseSchema.safeParse({ sourcePerformance: [] })
    expect(result.success).toBe(true)
    if (result.success) {
      expect(result.data.sourcePerformance).toHaveLength(0)
    }
  })

  it('rejects missing sourcePerformance field', () => {
    const result = sourcePerformanceResponseSchema.safeParse({})
    expect(result.success).toBe(false)
  })

  it('rejects incomplete source performance item', () => {
    const invalid = {
      sourcePerformance: [{
        source: 'POS_A',
        itemCount: 500,
        // missing all avg* fields
      }],
    }
    const result = sourcePerformanceResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})

describe('methodAccuracyResponseSchema', () => {
  const validMethodAccuracyData = {
    methodAccuracy: {
      totalConfirmed: 1000,
      searchCorrect: 850,
      searchAccuracyPct: 85.0,
      cosineCorrect: 820,
      cosineAccuracyPct: 82.0,
      editCorrect: 780,
      editAccuracyPct: 78.0,
      jaccardCorrect: 750,
      jaccardAccuracyPct: 75.0,
      llmCorrect: 920,
      llmAccuracyPct: 92.0,
      ensembleCorrect: 940,
      ensembleAccuracyPct: 94.0,
    },
  }

  it('parses valid method accuracy response', () => {
    const result = methodAccuracyResponseSchema.safeParse(validMethodAccuracyData)
    expect(result.success).toBe(true)
  })

  it('returns correct method accuracy structure', () => {
    const result = methodAccuracyResponseSchema.parse(validMethodAccuracyData)
    expect(result.methodAccuracy.totalConfirmed).toBe(1000)
    expect(result.methodAccuracy.ensembleAccuracyPct).toBe(94.0)
  })

  it('rejects missing methodAccuracy field', () => {
    const result = methodAccuracyResponseSchema.safeParse({})
    expect(result.success).toBe(false)
  })

  it('rejects incomplete methodAccuracy object', () => {
    const invalid = {
      methodAccuracy: {
        totalConfirmed: 1000,
        // missing all other fields
      },
    }
    const result = methodAccuracyResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })

  it('rejects non-number accuracy values', () => {
    const invalid = {
      methodAccuracy: {
        ...validMethodAccuracyData.methodAccuracy,
        searchAccuracyPct: 'high',
      },
    }
    const result = methodAccuracyResponseSchema.safeParse(invalid)
    expect(result.success).toBe(false)
  })
})

# Composition
# ===========
#
# Sequence composition counter.
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/BioSequences.jl/blob/master/LICENSE.md

"""
Sequence composition.

This is a subtype of `Associative{T,Int}`, and the `getindex` method returns the
number of occurrences of a symbol or a k-mer.
"""
struct Composition{T} <: Associative{T,Int}
    counts::Dict{T,Int}
end

function Composition(seq::MutableBioSequence{A}) where A <: NucleicAcidAlphabet
    counts = zeros(Int, 16)
    @inbounds for x in seq
        counts[reinterpret(UInt8, x) + 1] += 1
    end
    # TODO: resolve use of characters(A()).
    return Composition{eltype(A)}(count_array2dict(counts, characters(A())))
end

function Composition(seq::ReferenceSequence)
    counts = zeros(Int, 16)
    @inbounds for x in seq
        counts[reinterpret(UInt8, x) + 1] += 1
    end
    return Composition{DNA}(count_array2dict(counts, ACGTN))
end

function Composition(kmer::DNAKmer)
    counts = Dict{DNA,Int}()
    counts[DNA_A] = count_a(kmer)
    counts[DNA_C] = count_c(kmer)
    counts[DNA_G] = count_g(kmer)
    counts[DNA_T] = count_t(kmer)
    return Composition(counts)
end

function Composition(kmer::RNAKmer)
    counts = Dict{RNA,Int}()
    counts[RNA_A] = count_a(kmer)
    counts[RNA_C] = count_c(kmer)
    counts[RNA_G] = count_g(kmer)
    counts[RNA_U] = count_t(kmer)
    return Composition(counts)
end

function Composition(seq::AminoAcidSequence)
    # TODO: Resolve use of characters AminoAcid.
    counts = zeros(Int, length(characters(AminoAcidAlphabet())))
    @inbounds for x in seq
        counts[reinterpret(UInt8, x) + 1] += 1
    end
    return Composition{AminoAcid}(count_array2dict(counts, characters(AminoAcidAlphabet())))
end

function Composition(iter::EachKmerIterator{T}) where {T<:Kmer}
    counts = Dict{T,Int}()
    if kmersize(T) ≤ 8
        # This is faster for short k-mers.
        counts′ = zeros(Int, 4^kmersize(T))
        for (_, x) in iter
            @inbounds counts′[reinterpret(Int, x)+1] += 1
        end
        for x in 1:endof(counts′)
            @inbounds c = counts′[x]
            if c > 0
                counts[reinterpret(T, x-1)] = c
            end
        end
    else
        for (_, x) in iter
            get!(counts, x, 0)
            counts[x] += 1
        end
    end
    return Composition{T}(counts)
end

"""
    composition(seq | kmer_iter)

Calculate composition of biological symbols in `seq` or k-mers in `kmer_iter`.
"""
function composition(iter::Union{BioSequence,EachKmerIterator})
    return Composition(iter)
end

"""
    composition(iter)

A generalised composition algorithm, which computes the number of unique items
produced by an iterable.

# Example

```jlcon

# Example, counting unique sequences.

julia> a = dna"AAAAAAAATTTTTT"
14nt DNA Sequence:
AAAAAAAATTTTTT

julia> b = dna"AAAAAAAATTTTTT"
14nt DNA Sequence:
AAAAAAAATTTTTT

julia> c = a[5:10]
6nt DNA Sequence:
AAAATT

julia> composition([a, b, c])
Vector{BioSequences.BioSequence{BioSequences.DNAAlphabet{4}}} Composition:
  AAAATT         => 1
  AAAAAAAATTTTTT => 2
```
"""
function composition(iter)
    counts = Dict{eltype(iter), Int}()
    @inbounds for item in iter
        counts[item] = get(counts, item, 0) + 1
    end
    return Composition(counts)
end

function Base.:(==)(x::Composition{T}, y::Composition{T}) where T
    return x.counts == y.counts
end

function Base.length(comp::Composition)
    return length(comp.counts)
end

function Base.start(comp::Composition)
    return start(comp.counts)
end

function Base.done(comp::Composition, s)
    return done(comp.counts, s)
end

function Base.next(comp::Composition, s)
    return next(comp.counts, s)
end

function Base.getindex(comp::Composition{T}, x) where {T}
    return get(comp.counts, convert(T, x), 0)
end

function Base.copy(comp::Composition)
    return Composition(copy(comp.counts))
end

function Base.merge(comp::Composition{T}, other::Composition{T}) where T
    return merge!(copy(comp), other)
end

function Base.merge!(comp::Composition{T}, other::Composition{T}) where {T}
    for (x, c) in other
        comp.counts[x] = comp[x] + c
    end
    return comp
end

function Base.summary(::Composition{T}) where T
    if T == DNA
        return "DNA Composition"
    elseif T == RNA
        return "RNA Composition"
    elseif T == AminoAcid
        return "Amino Acid Composition"
    else
        return string(T, " Composition")
    end
end

function count_array2dict(counts, alphabet)
    counts′ = Dict{eltype(alphabet),Int}()
    sizehint!(counts′, countnz(counts))
    for x in alphabet
        @inbounds c = counts[convert(Int64,x)+1]
        if c > 0
            counts′[x] = c
        end
    end
    return counts′
end

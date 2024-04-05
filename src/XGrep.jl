module XGrep
using TextSearch, CodecZstd, CodecBzip2, CodecZlib, Comonicon
# Write your package code here.

function my_eachline(filterfun::Function, filename)
    if endswith(filename, ".gz")
        codec = GzipDecompressorStream
    elseif endswith(filename, ".bz2")
        codec = Bzip2DecompressorStream
    elseif endswith(filename, ".zst")
        codec = ZstdDecompressorStream
    else
        codec = nothing
    end

    if codec === nothing
        open(filename) do stream
            for (lineno, line) in enumerate(eachline(stream))
                filterfun(lineno, line, filename)
            end
        end
    else
        open(codec, filename) do stream
        for (lineno, line) in enumerate(eachline(stream))
            filterfun(lineno, line, filename)
        end
    end
end

#=function run_regex(; files::AbstractVector, query::String, print_file::Bool=true, print_lineno::Bool=true, print_line::Bool=true)
    re = Regex(query, "is")
    for filename in files
        my_eachline(filename) do lineno, line, filename
            if occursin(re, line)
                if print_line
                    print_file && print(filename, ":")
                    print_lineno && print(lineno, ":")
                    println(line)
                end
            end
        end
    end
end=#

function intsize(Q, D)
    i = 0
    for u in Q
        if u in D
            i += 1
        end
    end

    i
end
 
cosinesim(Q, D) = intsize(Q, D) / (sqrt(length(Q)) * sqrt(length(D)))

function get_text(line, line_format, field)
    if line_format === :raw
        line
    elseif line_format === :json
        JSON.parse(line)[field]
    else
        split(line, line_format)[field]
    end
end

function xgrep(line_format, field; files, query::String, print_prefix::Bool=true, textconfig=TextConfig(qlist=[3]), mincos::Float64=0.0)
    Q = Set(tokenize(identity, textconfig, query))
    D = Set{String}()
    for filename in files
        my_eachline(filename) do lineno, line, filename
            text = get_text(line, line_format, field)
            empty!(D)
            for u in tokenize(identity, textconfig, text)
                push!(D, u)
            end
            s = cosinesim(Q, D)
            if s > mincos
                print_prefix && print(filename, ":", lineno, ":", round(s; digits=4), ":")
                println(line)
            end
        end
    end
end

"""
filter lines matching some query using the cosine distance; the text is preprocessed and vectorized

# Args

- `query`: query specification
- `files`: files to filter

# Options

- `-m, --mincos=<float>`: minimum cosine distance between query and line to accept a line
- `-n, --nwords=<list>`: list of word tokenizers to use
- `-q, --qgrams=<list>`: list of character qgrams to use
- `-l, --line-format=<format>`: format of the line, it can be 'raw' (default), 'json', or some delimiting character
- `-f, --field=<number or key>`: the key having the text when '-ljson' or the column number if we use a delim character (e.g., '-l:')

# Flags
- `-i, --ignore-case`: case insenstive
- `--ignore-prefix`: ignores prefix in the output

"""
@main function main(query::String, files...;
        mincos::Float64=0.0,
        ignore_prefix::Bool=false,
        ignore_case::Bool=false,
        nwords::String="0",
        qgrams::String="3,5",
        line_format=:raw,
        field=1
    )

    qlist = Int[parse(Int, q) for q in split(qgrams, ',')]; sort!(qlist, rev=true); while length(qlist) > 0 && qlist[end] == 0; pop!(qlist); end
    nlist = Int[parse(Int, q) for q in split(nwords, ',')]; sort!(nlist, rev=true); while length(nlist) > 0 && nlist[end] == 0; pop!(nlist); end

    textconfig = TextConfig(; nlist, qlist, lc=ignore_prefix)
    line_format, field = if line_format == "raw"
        :raw, field
    elseif line_format == "json"
        :json, field
    else
        line_format, parse(Int, field)
    end

    xgrep(line_format, field; files, mincos, query, print_prefix=!ignore_prefix, textconfig)
end

end


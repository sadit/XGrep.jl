module XGrep
using TextSearch, CodecZlib, ArgParse
# Write your package code here.

function my_eachline(filterfun::Function, filename)
    if endswith(filename, ".gz")
        open(GzipDecompressorStream, filename) do stream
            for (lineno, line) in enumerate(eachline(stream))
                filterfun(lineno, line, filename)
            end
        end
    else
        open(filename) do stream
            for (lineno, line) in enumerate(eachline(stream))
                filterfun(lineno, line, filename)
            end
        end
    end
end

function run_regex(; files::AbstractVector, query::String, print_file::Bool=true, print_lineno::Bool=true, print_line::Bool=true)
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
end

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

function xgrep(; files::AbstractVector, query::String, print_prefix::Bool=true, textconfig=TextConfig(qlist=[3]), mincos::Float64=0.0)
    Q = Set(tokenize(identity, textconfig, query))
    D = Set{String}()
    for filename in files
        my_eachline(filename) do lineno, line, filename
            empty!(D)
            for u in tokenize(identity, textconfig, line)
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

function main(ARGS)
    spec = ArgParseSettings()

    @add_arg_table! spec begin
        "--query", "-q"
            help = "query pattern"
            required = true
        "--mincos", "-m"
            help = "minimum cosine similarity to accept a line"
            arg_type = Float64
            default = 0.0
        "--ignore-prefix"
            help = "ignore match information prefix"
            action = :store_true
        "--ignore-case", "-i"
            help = "ignore casing character information"
            action = :store_true
        "--nwords"
            help = "comma separated list of word-grams for filtering, e.g., '-n 1,2'; zero means for ignoring nwords"
            arg_type = String
            default = "0"
        "--qgrams"
            help = "comma separated list of character qgrams, i.e., '-q 3,5'; zero means for ignoring qgrams"
            arg_type = String
            default = "3"
        "files"
            help = "input files"
            required = true
            nargs = '*'
    end

    args = parse_args(ARGS, spec)

    qlist = Int[parse(Int, q) for q in split(args["qgrams"], ',')]; sort!(qlist, rev=true); while length(qlist) > 0 && qlist[end] == 0; pop!(qlist); end
    nlist = Int[parse(Int, q) for q in split(args["nwords"], ',')]; sort!(nlist, rev=true); while length(nlist) > 0 && nlist[end] == 0; pop!(nlist); end

    textconfig = TextConfig(; nlist, qlist, lc=args["ignore-prefix"])
    xgrep(; files=args["files"], mincos=args["mincos"], query=args["query"], print_prefix=!args["ignore-prefix"], textconfig)
    nothing
end

end


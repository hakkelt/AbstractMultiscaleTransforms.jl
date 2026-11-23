using Documenter, MultiscaleTransformsBase
using Documenter: Remotes

DocMeta.setdocmeta!(MultiscaleTransformsBase, :DocTestSetup, :(using MultiscaleTransformsBase); recursive = true)

makedocs(;
    modules = [MultiscaleTransformsBase],
    sitename = "MultiscaleTransformsBase.jl",
    repo = Remotes.GitHub("hakkelt", "MultiscaleTransformsBase.jl"),
    authors = "Tamás Hakkel",
    format = Documenter.HTML(; canonical = "https://hakkelt.github.io/MultiscaleTransformsBase.jl"),
    pages = [
        "Home" => "index.md",
        "Implement a transform" => "implement.md",
        "Concepts" => "concepts.md",
        "API reference" => "api.md",
    ],
    checkdocs = :public,
)

deploydocs(; repo = "github.com/hakkelt/MultiscaleTransformsBase.jl", devbranch = "master")

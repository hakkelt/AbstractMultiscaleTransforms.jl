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
        "Implementing a transform" => "implementing.md",
        "API Reference" => "api.md",
    ],
    checkdocs = :public,
)

deploydocs(; repo = "github.com/hakkelt/MultiscaleTransformsBase.jl", devbranch = "master")

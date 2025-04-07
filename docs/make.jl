using NsightCompute
using Documenter

DocMeta.setdocmeta!(NsightCompute, :DocTestSetup, :(using NsightCompute); recursive=true)

makedocs(;
    modules=[NsightCompute],
    authors="singularitti <singularitti@outlook.com> and contributors",
    sitename="NsightCompute.jl",
    format=Documenter.HTML(;
        canonical="https://singularitti.github.io/NsightCompute.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/singularitti/NsightCompute.jl",
    devbranch="main",
)

let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall
let Profiles = ../../Constants/Profiles.dhall
let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall

in

Pipeline.build 
    (ArtifactPipelines.pipeline 
        Artifacts.All
        DebianVersions.DebVersion.Bullseye 
        Profiles.Type.Standard 
        PipelineMode.Type.PullRequest
    )
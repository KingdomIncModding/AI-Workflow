# Source layout check

Run `Check-SourceLayout.ps1 -ModFolder <mod-root>` after adding C# source and before building. The local build workflow runs it automatically.

The checker uses the installed .NET 10 SDK's C# parser, with no NuGet package dependencies. It rejects handwritten partial type declarations (including disabled `#if` code) and multiple top-level types in one file. It only reads `src/`; its build output stays under the selected mod's ignored `_AI/Scratch/SourceLayout/`.

Folder placement and method responsibilities still require review: preserve established folders, keep patch/helper classes in their own files there, and extract real helper classes when an existing class spans responsibilities. Each method does one job; a class contains all its methods in one file. The checker does not decide whether a method has one responsibility.

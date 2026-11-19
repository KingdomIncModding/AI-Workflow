using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

if (args.Length != 1 || !Directory.Exists(args[0]))
{
    Console.Error.WriteLine("Usage: SourceLayout <mod-root>");
    return 2;
}

var mod = Path.GetFullPath(args[0]);
var src = Path.Combine(mod, "src");
var files = Directory.Exists(src) ? Directory.GetFiles(src, "*.cs", SearchOption.AllDirectories) : Array.Empty<string>();
var violations = new List<string>();
foreach (var file in files)
{
    var root = CSharpSyntaxTree.ParseText(File.ReadAllText(file), path: file).GetRoot();
    Inspect(root, file, allowTopLevelCheck: true);
    // Disabled code is also source: do not hide new partials behind #if.
    foreach (var disabled in root.DescendantTrivia().Where(t => t.IsKind(SyntaxKind.DisabledTextTrivia)))
        Inspect(CSharpSyntaxTree.ParseText(disabled.ToString()).GetRoot(), file, allowTopLevelCheck: false);
}

foreach (var violation in violations.Distinct()) Console.Error.WriteLine(violation);
if (violations.Count > 0)
{
    Console.Error.WriteLine("Keep each handwritten class complete in one file, inside its responsibility folder. See _AI/_shared/CODING_STANDARDS.md.");
    return 1;
}
Console.WriteLine($"Source layout OK: {Path.GetFileName(mod)} ({files.Length} C# files).");
return 0;

void Inspect(SyntaxNode root, string file, bool allowTopLevelCheck)
{
    var declarations = root.DescendantNodes().OfType<TypeDeclarationSyntax>().ToList();
    foreach (var declaration in declarations.Where(t => t.Modifiers.Any(SyntaxKind.PartialKeyword)))
    {
        var line = declaration.GetLocation().GetLineSpan().StartLinePosition.Line + 1;
        violations.Add($"{file}:{line}: partial {declaration.Identifier.ValueText}; combine its members into one class file in its responsibility folder.");
    }
    var topLevel = declarations.Where(t => !t.Ancestors().OfType<TypeDeclarationSyntax>().Any()).ToList();
    if (allowTopLevelCheck && topLevel.Count > 1)
        violations.Add($"{file}: multiple top-level types ({string.Join(", ", topLevel.Select(t => t.Identifier.ValueText))}); give each its own file in this folder.");
}

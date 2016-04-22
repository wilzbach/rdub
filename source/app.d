#!/usr/bin/env rdmd

/**
Allows to execute D code with dub modules
*/

void main(string[] args)
{
    import std.process: spawnProcess, Config, wait;
    auto file = args[1];
    auto modules = findModules(file);
    return;
}

import dparse.ast: ASTVisitor;

class ImportAnalyzer : ASTVisitor
{
    import dparse.ast;
public:
    alias visit = ASTVisitor.visit;

    ubyte[] b;
    string[][] modules;

    this(ubyte[] b)
    {
        this.b = b;
    }

    private void addIdentifierChain(inout(IdentifierChain) chain)
    {
        string[] s;
        foreach (ims; chain.identifiers)
        {
            s ~= [ims.text];
        }
        modules ~= s;
    }

    override void visit(const ImportDeclaration im)
    {
        import std.stdio;
        import std.conv;
        auto a = im;
        foreach (singleImport; im.singleImports)
        {
            addIdentifierChain(singleImport.identifierChain);
        }

        // token
        if (im.importBindings !is null)
        {
            addIdentifierChain(im.importBindings.singleImport.identifierChain);
        }
    }
}

string[][] findModules(string filename)
{
    import dparse.lexer;
    import dparse.parser;
    import std.stdio : File;
    import dparse.rollback_allocator : RollbackAllocator;
    RollbackAllocator rba;

    auto f = File(filename);
    immutable ulong fileSize = f.size();
    ubyte[] fileBytes = new ubyte[](fileSize);
    assert(f.rawRead(fileBytes).length == fileSize);
    StringCache cache = StringCache(StringCache.defaultBucketCount);
    LexerConfig config;
    config.stringBehavior = StringBehavior.source;
    config.fileName = filename;
    const(Token)[] tokens = getTokensForParser(fileBytes, config, &cache);
    auto dmod = parseModule(tokens, filename, &rba);
    ImportAnalyzer im = new ImportAnalyzer(fileBytes);
    im.visit(dmod);
    import std.stdio;
    writeln(im.modules);
    return im.modules;
}

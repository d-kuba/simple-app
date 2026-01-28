var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", (IConfiguration configuration) => 
{
    var secret = configuration["MyAppSecret"] ?? "Secret not found";
    return $"Hello World! Secret value: {secret}";
});

app.Run();

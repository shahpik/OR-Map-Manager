# Test we can throw it
@test_throws JuliaAppTemplate.App.JuliaAppTemplateException throw(JuliaAppTemplate.App.JuliaAppTemplateException("msg"))

# Test a log
err = JuliaAppTemplate.App.JuliaAppTemplateException("My message")
@test occursin("My message", sprint(showerror, err))
@test occursin("JuliaAppTemplateException", sprint(showerror, err))
class Views::HelpersSystemSpec::BuiltInOutputtingToRendering < Fortitude::Widget
  helper :concat, :transform => :return_output

  def content
    the_text = concat("this is the_text")
    p "text is: #{the_text}"
  end
end
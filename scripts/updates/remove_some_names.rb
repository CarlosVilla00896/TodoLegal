Document.all.each do |document|
  if document.issue_id == "Marcas de Fábrica" or document.issue_id == "Avisos Legales" or document.issue_id == "Gaceta"
    document.name = ""
    document.save
  end
end
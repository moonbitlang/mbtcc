
///|
pub fn ParserContext::preprocess(self: Self) -> Unit raise {
  let toks = self.alltoks;
  let tokinfos = self.tokinfos;
  let newtoks: Array[Token] = Array::new();
  let newtokinfos : Array[TokenInfo] = Array::new();
  loop (toks[:], tokinfos[:]) {
    ([Hash, Identifier("include"), StringLiteral(f), ..rest_toks], [_, _, _, ..rest_infos]) => {
      let path = @path.Path::new(self.source_file)
      let path = path.parent().unwrap()
      path.push(f)
      let path = path.to_absolute()
      let ctx = ParserContext::create_by_file(path)
      ctx.tokenize()
      ctx.preprocess()
      let _ = ctx.alltoks.pop() // remove EOF
      let _ = ctx.tokinfos.pop() // remove EOF
      newtoks.append(ctx.alltoks)
      newtokinfos.append(ctx.tokinfos)
      continue (rest_toks, rest_infos)
    }
    ([tok, ..rest_toks], [info, ..rest_infos]) => {
      newtoks.push(tok)
      newtokinfos.push(info)
      continue (rest_toks, rest_infos)
    }
    ([], []) => break
    ([], _) | (_, []) => {
      println("Mismatched tokens and token infos during preprocessing")
      panic()
    }
  }
  self.alltoks = newtoks;
  self.tokinfos = newtokinfos;
}

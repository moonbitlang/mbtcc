
///|
pub fn ParserContext::preprocess(self: Self) -> Unit raise {
  let toks = self.alltoks;
  let tokinfos = self.tokinfos;
  let newtoks: Array[Token] = Array::new();
  let newtokinfos : Array[TokenInfo] = Array::new();
  let defines: Map[String, (Array[Token], Array[TokenInfo])] = Map::new();
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
    ([Hash, Identifier("define"), Identifier(defname), .. toks], [_, _, name_info, ..infos]) => {
      let lineno = name_info.lineno
      let def_toks: Array[Token] = Array::new()
      let def_tokinfos: Array[TokenInfo] = Array::new()
      loop (toks, infos) {
        ([_, ..], [info, ..]) if info.lineno != lineno => break
        ([tok, ..rest_toks], [info, ..rest_infos]) => {
          def_toks.push(tok)
          def_tokinfos.push(info)
          continue (rest_toks, rest_infos)
        }
        ([], []) => break
        ([], _) | (_, []) => {
          println("Mismatched tokens and token infos during preprocessing")
          panic()
        }
      }
      defines[defname] = (def_toks, def_tokinfos)
    }
    ([Identifier(name), ..rest_toks], [info, ..rest_infos]) if defines.get(name) is Some((toks, infos)) => {
      newtoks.append(toks)
      newtokinfos.append(infos)
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

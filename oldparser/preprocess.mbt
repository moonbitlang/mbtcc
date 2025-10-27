// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
pub fn ParserContext::preprocess(self : Self) -> Unit raise {
  let toks = self.alltoks
  let tokinfos = self.tokinfos
  let newtoks : Array[Token] = Array::new()
  let newtokinfos : Array[TokenInfo] = Array::new()
  let defines : Map[String, (Array[Token], Array[TokenInfo])] = Map::new()
  loop (toks[:], tokinfos[:]) {
    (
      [Hash, Identifier("include"), StringLiteral(f), .. rest_toks],
      [_, _, _, .. rest_infos],
    ) => {
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
    (
      [Hash, Identifier("define"), Identifier(defname), .. toks],
      [_, _, name_info, .. infos],
    ) => {
      let lineno = name_info.lineno
      let def_toks : Array[Token] = Array::new()
      let def_tokinfos : Array[TokenInfo] = Array::new()
      let (rest_toks, rest_infos) = loop (toks, infos) {
        ([_, ..], [info, ..]) as r if info.lineno != lineno => break r
        ([tok, .. rest_toks], [info, .. rest_infos]) => {
          def_toks.push(tok)
          def_tokinfos.push(info)
          continue (rest_toks, rest_infos)
        }
        ([], []) => break (toks, infos)
        ([], _) | (_, []) => {
          println("Mismatched tokens and token infos during preprocessing")
          panic()
        }
      }
      defines[defname] = (def_toks, def_tokinfos)
      continue (rest_toks, rest_infos)
    }
    ([Identifier(name), .. rest_toks], [_, .. rest_infos]) if defines.get(name)
      is Some((toks, infos)) => {
      newtoks.append(toks)
      newtokinfos.append(infos)
      continue (rest_toks, rest_infos)
    }
    ([tok, .. rest_toks], [info, .. rest_infos]) => {
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
  self.alltoks = newtoks
  self.tokinfos = newtokinfos
}

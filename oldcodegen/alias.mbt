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
using @env {type Env}

///|
using @parser {type PrimExpr}

///|
using @parser {type ConstantExpr}

///|
using @parser {type PostFixExpr, type PostFixSuffix}

///|
using @parser {
  type UnaryExpr,
  type UnaryPrefix,
  type UnaryExprBody,
  type UnaryOperator,
}

///|
using @parser {type CastExpr}

///|
using @parser {type MultExpr, type MultOp}

///|
using @parser {type AddSubExpr, type AddSubOp}

///|
using @parser {type ShiftExpr, type ShiftOp}

///|
using @parser {type RelationalExpr, type RelationalOp}

///|
using @parser {type EqualityExpr, type EqualityOp}

///|
using @parser {type AndExpr, type ExclusiveOrExpr, type InclusiveOrExpr}

///|
using @parser {type LogicalAndExpr, type LogicalOrExpr}

///|
using @parser {type ConditionalExpr}

///|
using @parser {type AssignExpr}

///|
using @parser {type Expr}

///|
using @parser {type Declaration}

///|
using @parser {type DeclSpec}

///|
using @parser {type StorageClassSpec}

///|
using @parser {type TypeSpec}

///|
using @parser {type TypeQualifier}

///|
using @parser {type TypeSpecOrQualifier}

///|
using @parser {type StructSpec, type UnionSpec}

///|
using @parser {type StructDeclaration, type StructDeclarator}

///|
using @parser {type Declarator}

///|
using @parser {type Pointer}

///|
using @parser {type DirectDeclarator}

///|
using @parser {type InitDeclarator}

///|
using @parser {type Initializer}

///|
using @parser {type Designator}

///|
using @parser {type EnumSpec}

///|
using @parser {type Enumerator}

///|
using @parser {type FunctionSpec}

///|
using @parser {type AlignmentSpec}

///|
using @parser {type TypeName}

///|
using @parser {type AbstractDeclarator}

///|
using @parser {type DirectAbstractDeclarator}

///|
using @parser {type Statement}

///|
using @parser {type LabeledStatement}

///|
using @parser {type CompoundStatement}

///|
using @parser {type BlockItem}

///|
using @parser {type SelectionStatement}

///|
using @parser {type IterationStatement}

///|
using @parser {type ForCondition, type ForInit}

///|
using @parser {type JumpStatement}

///|
using @parser {type CompilationUnit}

///|
using @parser {type ExternalDeclaration}

///|
using @parser {type FunctionDefinition}

///|
using @parser {type ParameterTypeList}

///|
using @parser {type ParameterDecl}

///|
using @parser {type ParamDeclarator}

///|
using @parser {type ParserContext}

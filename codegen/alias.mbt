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
typealias @env.Env

///|
typealias @parser.PrimExpr

///|
typealias @parser.ConstantExpr

///|
typealias @parser.(PostFixExpr, PostFixSuffix)

///|
typealias @parser.(UnaryExpr, UnaryPrefix, UnaryExprBody, UnaryOperator)

///|
typealias @parser.CastExpr

///|
typealias @parser.(MultExpr, MultOp)

///|
typealias @parser.(AddSubExpr, AddSubOp)

///|
typealias @parser.(ShiftExpr, ShiftOp)

///|
typealias @parser.(RelationalExpr, RelationalOp)

///|
typealias @parser.(EqualityExpr, EqualityOp)

///|
typealias @parser.(AndExpr, ExclusiveOrExpr, InclusiveOrExpr)

///|
typealias @parser.(LogicalAndExpr, LogicalOrExpr)

///|
typealias @parser.ConditionalExpr

///|
typealias @parser.AssignExpr

///|
typealias @parser.Expr

///|
typealias @parser.Declaration

///|
typealias @parser.DeclSpec

///|
typealias @parser.StorageClassSpec

///|
typealias @parser.TypeSpec

///|
typealias @parser.TypeQualifier

///|
typealias @parser.TypeSpecOrQualifier

///|
typealias @parser.(StructSpec, UnionSpec)

///|
typealias @parser.(StructDeclaration, StructDeclarator)

///|
typealias @parser.Declarator

///|
typealias @parser.Pointer

///|
typealias @parser.DirectDeclarator

///|
typealias @parser.InitDeclarator

///|
typealias @parser.Initializer

///|
typealias @parser.Designator

///|
typealias @parser.EnumSpec

///|
typealias @parser.Enumerator

///|
typealias @parser.FunctionSpec

///|
typealias @parser.AlignmentSpec

///|
typealias @parser.TypeName

///|
typealias @parser.AbstractDeclarator

///|
typealias @parser.DirectAbstractDeclarator

///|
typealias @parser.Statement

///|
typealias @parser.LabeledStatement

///|
typealias @parser.CompoundStatement

///|
typealias @parser.BlockItem

///|
typealias @parser.SelectionStatement

///|
typealias @parser.IterationStatement

///|
typealias @parser.(ForCondition, ForInit)

///|
typealias @parser.JumpStatement

///|
typealias @parser.CompilationUnit

///|
typealias @parser.ExternalDeclaration

///|
typealias @parser.FunctionDefinition

///|
typealias @parser.ParameterTypeList

///|
typealias @parser.ParameterDecl

///|
typealias @parser.ParamDeclarator

///|
typealias @parser.ParserContext

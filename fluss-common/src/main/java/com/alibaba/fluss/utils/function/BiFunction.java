/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.alibaba.fluss.utils.function;

import com.alibaba.fluss.annotation.PublicEvolving;

/**
 * Function which takes three arguments.
 *
 * @param <S> type of the first argument
 * @param <T> type of the second argument
 * @param <R> type of the return value
 * @since 0.1
 */
@PublicEvolving
@FunctionalInterface
public interface BiFunction<S, T, R> {

    /**
     * Applies this function to the given arguments.
     *
     * @param s the first function argument
     * @param t the second function argument
     * @return the function result
     */
    R apply(S s, T t);
}
